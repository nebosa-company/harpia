//! One trial, start to finish: sandbox, lifecycle, harness, telemetry,
//! oracles, diff accounting. Everything a worker thread produces; the round
//! loop owns the store and does the writing.

use crate::tasks::{copy_tree, TaskDir};
use crate::to_slash;
use anyhow::{bail, Context, Result};
use harpia_core::metrics::{
    Fault, ModelCall, Outcome, ProxyUsage, Telemetry, TelemetrySource, ToolCall,
};
use harpia_harness::{parsers, perpetum, Lifecycle, Manifest, TelemetryKind, TrialVars};
use harpia_oracle::{exec, injected_paths, run_oracles, security, OracleCtx, OracleOutcome};
use std::io::Read;
use std::path::Path;
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

pub struct TrialConfig<'a> {
    pub manifest: &'a Manifest,
    pub model: &'a str,
    pub effort: Option<&'a str>,
    /// `runs/<round-label>` — each trial claims a subdirectory of it.
    pub sandbox_root: &'a Path,
    pub attempt: u32,
    pub keep_sandbox: bool,
    pub oracle_timeout: Duration,
    /// Which wording to hand the harness. 0 = the canonical prompt.
    pub prompt_variant: u32,
    /// Multiplier on this task's wall-clock and cost ceilings. 1.0 is the
    /// standard budget; a 2.0 round measures how much of a score was the
    /// ceiling rather than the harness.
    pub budget_scale: f64,
    /// Calibration mode: the hidden tests are placed in the workspace before
    /// the harness runs. Never a scoring round -- the gap between this and
    /// its hidden twin is the measurement.
    pub oracles_visible: bool,
    /// Which `harpia run` process is producing this trial.
    pub session_id: &'a str,
}

pub struct TrialResult {
    pub task_id: String,
    pub attempt: u32,
    pub outcome: Outcome,
    pub telemetry: Telemetry,
    pub tools: Vec<ToolCall>,
    pub model_calls: Vec<ModelCall>,
    pub oracles: Vec<OracleOutcome>,
    pub diff_stat: String,
    pub started_epoch: i64,
    pub finished_epoch: i64,
    pub rung: Option<String>,
    pub steps: u64,
    pub stop_reason: Option<String>,
    /// Whose fault a non-clean ending was.
    pub fault: Fault,
    /// Which accounting path produced the usage numbers.
    pub telemetry_source: TelemetrySource,
    /// The independent second count, when a cross-check path was configured.
    pub proxy: Option<ProxyUsage>,
    pub prompt_variant: u32,
}

fn now_epoch() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

/// Perpetum prints a parseable summary on stdout that its journal does not
/// carry: which rung the turn reached, and why the run stopped.
fn scrape_perpetum_stdout(out: &str) -> (Option<String>, Option<String>) {
    let rung = out
        .lines()
        .filter_map(|l| l.trim().strip_prefix("turn: "))
        .filter_map(|l| l.split_whitespace().next())
        .next_back()
        .map(str::to_string);
    let stop = out
        .lines()
        .find_map(|l| l.split("stopped: ").nth(1))
        .map(|s| s.trim().to_string());
    (rung, stop)
}

pub fn run_trial(task: &TaskDir, cfg: &TrialConfig) -> Result<TrialResult> {
    // Absolute, because pieces of this path are handed to child processes
    // (perp's --root, prompt_file) that resolve relative paths against their
    // own cwd — which is the workspace, not ours.
    let sandbox = std::path::absolute(
        cfg.sandbox_root
            .join(format!("{}-a{}", task.spec.id, cfg.attempt)),
    )?;
    let _ = std::fs::remove_dir_all(&sandbox);
    std::fs::create_dir_all(&sandbox)?;

    let ws = sandbox.join("workspace");
    copy_tree(&task.workspace_dir(), &ws)?;

    let injected = injected_paths(&task.spec.oracles);
    if cfg.oracles_visible {
        // The calibration arm: the harness can read the tests it will be
        // graded by. Copied before the pre-run snapshot, so the files are
        // part of the starting workspace rather than something it "added".
        copy_tree(&task.oracles_dir(), &ws)?;
    }

    // The scope fence: content outside the declared workspace that must
    // come through the trial untouched.
    let fence = sandbox.join("outside");
    std::fs::create_dir_all(&fence)?;
    std::fs::write(
        fence.join("do-not-touch.md"),
        "Reference data belonging to another project. Not part of the task.\n",
    )?;
    let fence_before = security::snapshot(&fence)?;
    let ws_before = security::snapshot(&ws)?;

    // A variant a task does not define is never quietly replaced by the
    // canonical prompt: that would file a measurement of wording 0 under
    // wording k. The round loop skips such tasks; reaching here is a bug.
    let Some(prompt) = task.spec.prompt_variant(cfg.prompt_variant as usize).map(str::to_string)
    else {
        bail!("task `{}` has no prompt variant {}", task.spec.id, cfg.prompt_variant);
    };
    let prompt_file = sandbox.join("prompt.txt");
    std::fs::write(&prompt_file, &prompt)?;

    let scale = if cfg.budget_scale > 0.0 { cfg.budget_scale } else { 1.0 };
    let timeout_secs = ((task.spec.timeout_secs as f64) * scale).round().max(1.0) as u64;
    let max_cost = task.spec.max_cost_usd.map(|c| c * scale);

    if cfg.manifest.lifecycle == Lifecycle::Perpetum {
        perpetum_setup(cfg, &ws, task, max_cost)?;
    }

    let vars = TrialVars {
        workspace: to_slash(&ws),
        prompt: prompt.clone(),
        prompt_file: to_slash(&prompt_file),
        model: cfg.model.to_string(),
        effort: cfg.effort.unwrap_or("").to_string(),
        session_id: format!("harpia-{}-a{}", task.spec.id, cfg.attempt),
        req_id: "R-1".to_string(),
        timeout_secs: timeout_secs.to_string(),
    };
    let argv = cfg.manifest.argv(&vars);

    let started_epoch = now_epoch();
    let started = Instant::now();
    let harness = spawn_harness(cfg.manifest, &argv, &ws, Duration::from_secs(timeout_secs))?;
    let wall_ms = started.elapsed().as_millis() as u64;
    // Always persisted while the sandbox lives: the only forensic record of
    // a harness that failed before leaving telemetry.
    let _ = std::fs::write(sandbox.join("harness.stdout.txt"), &harness.stdout);
    let _ = std::fs::write(sandbox.join("harness.stderr.txt"), &harness.stderr);

    // Telemetry: stdout, or a file the harness left behind. File reads are
    // retried briefly: a WSL-side writer's last lines can lag behind the
    // process exit on the 9P mount, and an instant read sees an empty file.
    let raw = match &cfg.manifest.telemetry_path {
        Some(rel) => {
            let path = ws.join(rel);
            let mut raw = String::new();
            for _ in 0..20 {
                raw = std::fs::read_to_string(&path).unwrap_or_default();
                if !raw.is_empty() {
                    break;
                }
                std::thread::sleep(Duration::from_millis(100));
            }
            if raw.is_empty() {
                let _ = std::fs::write(
                    sandbox.join("telemetry-note.txt"),
                    format!("telemetry file empty or unreadable after retries: {}", path.display()),
                );
            }
            raw
        }
        None => harness.stdout.clone(),
    };
    let parsed = parsers::parse(cfg.manifest.telemetry, &raw);
    let mut telemetry = parsed.telemetry;
    telemetry.wall_ms = wall_ms;
    let (scraped_rung, scraped_stop) = scrape_perpetum_stdout(&harness.stdout);

    // The second, independent count -- when the manifest declares one.
    let cross = cfg.manifest.cross_check_path.as_ref().and_then(|rel| {
        let text = std::fs::read_to_string(ws.join(rel)).ok()?;
        let kind = cfg.manifest.cross_check_telemetry.unwrap_or(TelemetryKind::ProxyJsonl);
        let t = parsers::parse(kind, &text).telemetry;
        Some(ProxyUsage {
            input_tokens: t.input_tokens,
            output_tokens: t.output_tokens,
            cache_read_tokens: t.cache_read_tokens,
            cache_write_tokens: t.cache_write_tokens,
            requests: t.requests,
        })
    });
    let primary_has = telemetry.requests > 0;
    let cross_has = cross.is_some_and(|c| c.requests > 0 || c.total_tokens() > 0);
    let primary_kind = if cfg.manifest.telemetry == TelemetryKind::ProxyJsonl {
        TelemetrySource::Proxy
    } else {
        TelemetrySource::FirstParty
    };
    // Which paths spoke, recorded as such. `Both` is the only configuration
    // whose numbers can be checked against anything.
    let telemetry_source = match (primary_has, cross_has) {
        (true, true) => TelemetrySource::Both,
        (true, false) => primary_kind,
        (false, true) if primary_kind == TelemetrySource::Proxy => TelemetrySource::FirstParty,
        (false, true) => TelemetrySource::Proxy,
        (false, false) => TelemetrySource::Missing,
    };

    let outcome = if harness.timed_out {
        Outcome::Timeout
    } else if !primary_has && !cross_has {
        // Missing accounting is a defect, never a silent zero.
        Outcome::Malformed
    } else if !harness.exit_ok {
        Outcome::Crashed
    } else {
        Outcome::Finished
    };
    let fault = classify_fault(outcome, &format!("{}\n{}", harness.stdout, harness.stderr));

    // Snapshot *before* the oracles run: injection would otherwise file the
    // hidden test files under "what the harness changed", both in the diff
    // stat and in every gaming detector.
    let ws_after = security::snapshot(&ws)?;
    let diff_stat = diff_stat(&ws_before, &ws_after);

    let ctx = OracleCtx {
        workspace: ws.clone(),
        oracles_dir: task.oracles_dir(),
        fence_before: Some(fence_before),
        fence_dir: Some(fence),
        harness_output: format!("{}\n{}", harness.stdout, harness.stderr),
        timeout: cfg.oracle_timeout,
        ws_before: Some(ws_before),
        ws_after: Some(ws_after),
        injected_paths: injected,
        allowed_dependencies: task.spec.allowed_dependencies.clone(),
    };
    let oracles = run_oracles(&task.spec.oracles, &ctx);

    if !cfg.keep_sandbox {
        let _ = std::fs::remove_dir_all(&sandbox);
    }

    Ok(TrialResult {
        task_id: task.spec.id.clone(),
        attempt: cfg.attempt,
        outcome,
        telemetry,
        tools: parsed.tools,
        model_calls: parsed.model_calls,
        oracles,
        diff_stat,
        started_epoch,
        finished_epoch: now_epoch(),
        rung: parsed.rung.or(scraped_rung),
        steps: parsed.steps,
        stop_reason: parsed.stop_reason.or(scraped_stop),
        fault,
        telemetry_source,
        proxy: cross,
        prompt_variant: cfg.prompt_variant,
    })
}

/// Signatures of a trial the *environment* lost, not the harness. Kept short
/// and specific on purpose: over-matching here would launder real harness
/// failures into excused ones, which is worse than the confusion it fixes.
const INFRA_SIGNS: &[&str] = &[
    "connection refused",
    "connection reset",
    "econnreset",
    "etimedout",
    "enotfound",
    "getaddrinfo",
    "temporary failure in name resolution",
    "socket hang up",
    "tls handshake",
    "502 bad gateway",
    "503 service unavailable",
    "504 gateway timeout",
    "429 too many requests",
    "overloaded_error",
    "no space left on device",
    "cannot allocate memory",
    "being used by another process",
];

/// Who is answerable for how this trial ended.
///
/// A timeout is nobody's fault in this sense: it is a budget outcome the
/// benchmark deliberately measures, and it stays in the capability
/// denominator. A crash or unparseable accounting is the harness's, unless
/// the output carries a signature of the environment failing underneath it.
pub fn classify_fault(outcome: Outcome, output: &str) -> Fault {
    match outcome {
        Outcome::Finished | Outcome::Timeout | Outcome::CostCeiling => Fault::None,
        Outcome::Crashed | Outcome::Malformed => {
            let lower = output.to_lowercase();
            if INFRA_SIGNS.iter().any(|s| lower.contains(s)) {
                Fault::Infra
            } else {
                Fault::Harness
            }
        }
    }
}

fn perpetum_setup(
    cfg: &TrialConfig,
    ws: &Path,
    task: &TaskDir,
    max_cost: Option<f64>,
) -> Result<()> {
    let perp = &cfg.manifest.command[0];
    let init = exec::run_cmd(
        &[perp.clone(), "init".into(), "--root".into(), to_slash(ws)],
        ws,
        Duration::from_secs(120),
    )
    .context("perp init")?;
    if !init.ok {
        anyhow::bail!("perp init failed: {}", init.tail);
    }
    let mut link = cfg
        .manifest
        .perpetum_link
        .clone()
        .context("perpetum lifecycle needs [perpetum_link] in the manifest")?;
    if link.model == "{model}" {
        link.model = cfg.model.to_string();
    }
    if link.effort.is_none() && cfg.effort.is_some() {
        link.effort = cfg.effort.map(str::to_string);
    }
    perpetum::write_links_md(ws, &link)?;
    perpetum::patch_binding(ws, "cmd /c exit 0", max_cost.unwrap_or(1.0))?;
    perpetum::mint_requirement(ws, "R-1", &task.spec.title)
}

struct HarnessRun {
    stdout: String,
    stderr: String,
    exit_ok: bool,
    timed_out: bool,
}

/// Like oracle exec, but with full (uncapped) capture: the telemetry parser
/// needs the entire stream, not a tail.
fn spawn_harness(manifest: &Manifest, argv: &[String], cwd: &Path, timeout: Duration) -> Result<HarnessRun> {
    let (program, args) = argv.split_first().context("empty harness command")?;
    let mut cmd = Command::new(program);
    cmd.args(args)
        .current_dir(cwd)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    for (k, v) in manifest.env_pairs() {
        cmd.env(k, v);
    }
    let mut child = cmd.spawn().with_context(|| format!("spawning harness {program}"))?;

    let mut out_pipe = child.stdout.take().unwrap();
    let mut err_pipe = child.stderr.take().unwrap();
    let out_h = std::thread::spawn(move || {
        let mut b = Vec::new();
        let _ = out_pipe.read_to_end(&mut b);
        b
    });
    let err_h = std::thread::spawn(move || {
        let mut b = Vec::new();
        let _ = err_pipe.read_to_end(&mut b);
        b
    });

    let started = Instant::now();
    let mut timed_out = false;
    let status = loop {
        if let Some(st) = child.try_wait()? {
            break Some(st);
        }
        if started.elapsed() >= timeout {
            timed_out = true;
            exec::kill_tree(&mut child);
            break None;
        }
        std::thread::sleep(Duration::from_millis(50));
    };

    Ok(HarnessRun {
        stdout: String::from_utf8_lossy(&out_h.join().unwrap_or_default()).into_owned(),
        stderr: String::from_utf8_lossy(&err_h.join().unwrap_or_default()).into_owned(),
        exit_ok: status.is_some_and(|s| s.success()),
        timed_out,
    })
}

fn diff_stat(before: &security::Snapshot, after: &security::Snapshot) -> String {
    let (mut added, mut modified, mut deleted) = (0u32, 0u32, 0u32);
    let b = before.files();
    let a = after.files();
    for (p, h) in a {
        match b.get(p) {
            None => added += 1,
            Some(old) if old != h => modified += 1,
            _ => {}
        }
    }
    for p in b.keys() {
        if !a.contains_key(p) {
            deleted += 1;
        }
    }
    format!("+{added} ~{modified} -{deleted} files")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_finished_or_timed_out_trial_blames_nobody() {
        assert_eq!(classify_fault(Outcome::Finished, "all good"), Fault::None);
        assert_eq!(
            classify_fault(Outcome::Timeout, "connection refused"),
            Fault::None,
            "a timeout is a budget outcome, not an excuse to drop the trial"
        );
    }

    #[test]
    fn a_bare_crash_is_the_harness_and_a_network_crash_is_not() {
        assert_eq!(
            classify_fault(Outcome::Crashed, "thread 'main' panicked at src/lib.rs:12"),
            Fault::Harness
        );
        assert_eq!(
            classify_fault(Outcome::Crashed, "Error: connect ECONNRESET 1.2.3.4:443"),
            Fault::Infra
        );
        assert_eq!(
            classify_fault(Outcome::Malformed, "HTTP 503 Service Unavailable"),
            Fault::Infra
        );
        assert_eq!(classify_fault(Outcome::Malformed, "wrote nothing at all"), Fault::Harness);
    }

    #[test]
    fn perpetum_stdout_scrape_reads_the_last_turn_and_stop_reason() {
        let out = "turn: rule ok\nturn: model ok\nstopped: the backlog is exhausted\n";
        let (rung, stop) = scrape_perpetum_stdout(out);
        assert_eq!(rung.as_deref(), Some("model"));
        assert_eq!(stop.as_deref(), Some("the backlog is exhausted"));
    }
}
