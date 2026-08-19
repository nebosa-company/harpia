//! One trial, start to finish: sandbox, lifecycle, harness, telemetry,
//! oracles, diff accounting. Everything a worker thread produces; the round
//! loop owns the store and does the writing.

use crate::tasks::{copy_tree, TaskDir};
use crate::to_slash;
use anyhow::{Context, Result};
use harpia_core::metrics::{Outcome, Telemetry};
use harpia_harness::{parsers, perpetum, Lifecycle, Manifest, TrialVars};
use harpia_oracle::{exec, run_oracles, security, OracleCtx, OracleOutcome};
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
}

pub struct TrialResult {
    pub task_id: String,
    pub attempt: u32,
    pub outcome: Outcome,
    pub telemetry: Telemetry,
    pub tools: Vec<(String, bool)>,
    pub oracles: Vec<OracleOutcome>,
    pub diff_stat: String,
}

pub fn run_trial(task: &TaskDir, cfg: &TrialConfig) -> Result<TrialResult> {
    let sandbox = cfg
        .sandbox_root
        .join(format!("{}-a{}", task.spec.id, cfg.attempt));
    let _ = std::fs::remove_dir_all(&sandbox);
    std::fs::create_dir_all(&sandbox)?;

    let ws = sandbox.join("workspace");
    copy_tree(&task.workspace_dir(), &ws)?;

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

    let prompt_file = sandbox.join("prompt.txt");
    std::fs::write(&prompt_file, &task.spec.prompt)?;

    if cfg.manifest.lifecycle == Lifecycle::Perpetum {
        perpetum_setup(cfg, &ws, task)?;
    }

    let vars = TrialVars {
        workspace: to_slash(&ws),
        prompt: task.spec.prompt.clone(),
        prompt_file: to_slash(&prompt_file),
        model: cfg.model.to_string(),
        effort: cfg.effort.unwrap_or("").to_string(),
        session_id: format!("harpia-{}-a{}", task.spec.id, cfg.attempt),
        req_id: "R-1".to_string(),
        timeout_secs: task.spec.timeout_secs.to_string(),
    };
    let argv = cfg.manifest.argv(&vars);

    let started = Instant::now();
    let harness = spawn_harness(cfg.manifest, &argv, &ws, Duration::from_secs(task.spec.timeout_secs))?;
    let wall_ms = started.elapsed().as_millis() as u64;

    // Telemetry: stdout, or a file the harness left in the workspace.
    let raw = match &cfg.manifest.telemetry_path {
        Some(rel) => std::fs::read_to_string(ws.join(rel)).unwrap_or_default(),
        None => harness.stdout.clone(),
    };
    let parsed = parsers::parse(cfg.manifest.telemetry, &raw);
    let mut telemetry = parsed.telemetry;
    telemetry.wall_ms = wall_ms;

    let outcome = if harness.timed_out {
        Outcome::Timeout
    } else if telemetry.requests == 0 {
        // Missing accounting is a defect, never a silent zero.
        Outcome::Malformed
    } else if !harness.exit_ok {
        Outcome::Crashed
    } else {
        Outcome::Finished
    };

    let ctx = OracleCtx {
        workspace: ws.clone(),
        oracles_dir: task.oracles_dir(),
        fence_before: Some(fence_before),
        fence_dir: Some(fence),
        harness_output: format!("{}\n{}", harness.stdout, harness.stderr),
        timeout: cfg.oracle_timeout,
    };
    let oracles = run_oracles(&task.spec.oracles, &ctx);

    let ws_after = security::snapshot(&ws)?;
    let diff_stat = diff_stat(&ws_before, &ws_after);

    if !cfg.keep_sandbox {
        let _ = std::fs::remove_dir_all(&sandbox);
    }

    Ok(TrialResult {
        task_id: task.spec.id.clone(),
        attempt: cfg.attempt,
        outcome,
        telemetry,
        tools: parsed.tools,
        oracles,
        diff_stat,
    })
}

fn perpetum_setup(cfg: &TrialConfig, ws: &Path, task: &TaskDir) -> Result<()> {
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
    for (k, v) in &manifest.env {
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
