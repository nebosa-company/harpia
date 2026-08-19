//! A round: (harness, model, effort) over the corpus, with attempts, resume,
//! and a worker pool. Workers run trials; the round loop owns the store and
//! writes each result before handing out more work.

use crate::tasks::TaskDir;
use crate::trial::{run_trial, TrialConfig, TrialResult};
use crate::{content, toolchain};
use anyhow::Result;
use harpia_core::rng::Rng;
use harpia_harness::Manifest;
use harpia_store::{RoundStart, Store, TrialProvenance, TrialRecord};
use std::collections::VecDeque;
use std::path::PathBuf;
use std::sync::mpsc;
use std::sync::{Arc, Mutex};
use std::time::Duration;

pub struct RoundConfig {
    pub label: String,
    pub model: String,
    pub effort: Option<String>,
    pub tasks_sha: String,
    pub attempts: u32,
    pub jobs: usize,
    pub runs_dir: PathBuf,
    pub keep_sandbox: bool,
    pub oracle_timeout_secs: u64,
    /// Prompt wording for the whole round. 0 = canonical.
    pub prompt_variant: u32,
    /// Multiplier on every task's wall-clock and cost ceiling.
    pub budget_scale: f64,
    /// Calibration round: hidden tests placed in the workspace up front.
    pub oracles_visible: bool,
    /// Shuffle the work list with this seed. Two rounds sharing it ran the
    /// corpus in the same sequence, which is what makes an order effect
    /// testable rather than speculative.
    pub order_seed: Option<u64>,
    pub notes: Option<String>,
}

impl Default for RoundConfig {
    fn default() -> Self {
        Self {
            label: String::new(),
            model: String::new(),
            effort: None,
            tasks_sha: String::new(),
            attempts: 1,
            jobs: 1,
            runs_dir: PathBuf::from("runs"),
            keep_sandbox: false,
            oracle_timeout_secs: 600,
            prompt_variant: 0,
            budget_scale: 1.0,
            oracles_visible: false,
            order_seed: None,
            notes: None,
        }
    }
}

pub struct RoundOutcome {
    pub round_id: i64,
    pub ran: usize,
    pub skipped: usize,
    /// Trials that produced no result; unrecorded, so resume retries them.
    pub failed: usize,
    /// Tasks left unmeasured because they do not define the round's prompt
    /// variant. Reported, never silently run with the canonical wording.
    pub no_variant: usize,
}

pub fn run_round(
    store: &mut Store,
    manifest: &Manifest,
    tasks: &[TaskDir],
    cfg: &RoundConfig,
) -> Result<RoundOutcome> {
    // The harness's own version, not Harpia's -- a report prints "perp 0.4.0",
    // and recording our version there made every harness look identical.
    let harness_version = probe_harness_version(manifest);
    store.upsert_harness(
        &manifest.id,
        env!("CARGO_PKG_VERSION"),
        harness_version.as_deref(),
        &format!("{manifest:?}"),
    )?;
    // Hash every task up front: the trials record what they actually ran
    // against, so a later corpus edit cannot retroactively make two rounds
    // look comparable.
    let mut shas: Vec<String> = Vec::with_capacity(tasks.len());
    for t in tasks {
        let sha = content::content_sha(t).unwrap_or_default();
        store.upsert_task_full(
            &t.spec.id,
            &format!("{:?}", t.spec.stack).to_lowercase(),
            &format!("{:?}", t.spec.tier).to_lowercase(),
            &t.spec.title,
            &t.spec_toml()?,
            (!sha.is_empty()).then_some(sha.as_str()),
            t.spec.family.map(|f| format!("{f:?}").to_lowercase()).as_deref(),
        )?;
        shas.push(sha);
    }
    let toolchain = toolchain::probe_json();
    // One id per `harpia run` process. A round assembled over several
    // sessions can then be checked for a batch effect instead of being
    // assumed homogeneous.
    let session_id = format!("s{}-{}", std::process::id(), now_epoch());
    // Borrowed as &str so the worker closures copy the reference instead of
    // moving the String out from under the round loop.
    let session: &str = session_id.as_str();

    let round_id = match store.round_id(&cfg.label)? {
        Some(id) => id,
        None => store.begin_round_full(&RoundStart {
            label: &cfg.label,
            harness_id: &manifest.id,
            model: &cfg.model,
            effort: cfg.effort.as_deref(),
            tasks_sha: &cfg.tasks_sha,
            started_at: &now_iso(),
            link_kind: manifest
                .perpetum_link
                .as_ref()
                .map(|l| l.kind.as_str())
                .or(Some(match manifest.telemetry {
                    harpia_harness::TelemetryKind::ClaudeStreamJson => "claude-code",
                    harpia_harness::TelemetryKind::ProxyJsonl => "http-proxy",
                    _ => "subprocess",
                })),
            params: Some(&format!("{:?}", manifest.command)),
            jobs: Some(cfg.jobs as u32),
            corpus_size: Some(tasks.len() as u32),
            harpia_version: Some(env!("CARGO_PKG_VERSION")),
            started_epoch: Some(now_epoch()),
            order_seed: cfg.order_seed.map(|s| s as i64),
            budget_scale: Some(cfg.budget_scale),
            prompt_variant: Some(cfg.prompt_variant),
            oracles_visible: Some(cfg.oracles_visible),
            toolchain: Some(&toolchain),
            notes: cfg.notes.as_deref(),
            ..Default::default()
        })?,
    };
    let done = store.done_attempts(round_id)?;

    let sandbox_root = cfg.runs_dir.join(&cfg.label);
    std::fs::create_dir_all(&sandbox_root)?;

    // Work list: every (task, attempt) not already recorded.
    let mut queued: Vec<(usize, u32)> = Vec::new();
    let mut skipped = 0usize;
    let mut failed = 0usize;
    let mut no_variant = 0usize;
    for (i, t) in tasks.iter().enumerate() {
        if t.spec.prompt_variant(cfg.prompt_variant as usize).is_none() {
            no_variant += 1;
            continue;
        }
        for attempt in 1..=cfg.attempts {
            if done.contains(&(t.spec.id.clone(), attempt)) {
                skipped += 1;
            } else {
                queued.push((i, attempt));
            }
        }
    }
    if let Some(seed) = cfg.order_seed {
        Rng::new(seed).shuffle(&mut queued);
    }
    if no_variant > 0 {
        eprintln!(
            "  {no_variant} task(s) define no prompt variant {} -- left unmeasured",
            cfg.prompt_variant
        );
    }
    let work: VecDeque<(usize, u32)> = queued.into_iter().collect();
    let total = work.len();

    let queue = Arc::new(Mutex::new(work));
    let (tx, rx) = mpsc::channel::<Result<(TrialResult, usize)>>();
    let jobs = cfg.jobs.max(1);
    std::thread::scope(|scope| -> Result<()> {
        for _ in 0..jobs {
            let queue = Arc::clone(&queue);
            let tx = tx.clone();
            let sandbox_root = sandbox_root.clone();
            scope.spawn(move || loop {
                let job = queue.lock().unwrap().pop_front();
                let Some((i, attempt)) = job else { break };
                let tcfg = TrialConfig {
                    manifest,
                    model: &cfg.model,
                    effort: cfg.effort.as_deref(),
                    sandbox_root: &sandbox_root,
                    attempt,
                    keep_sandbox: cfg.keep_sandbox,
                    oracle_timeout: Duration::from_secs(cfg.oracle_timeout_secs),
                    prompt_variant: cfg.prompt_variant,
                    budget_scale: cfg.budget_scale,
                    oracles_visible: cfg.oracles_visible,
                    session_id: session,
                };
                // A panic inside one trial must not take the round down with
                // it — round 3 died at trial 47 to a UTF-8 slice panic.
                let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                    run_trial(&tasks[i], &tcfg)
                }))
                .unwrap_or_else(|p| {
                    let msg = p
                        .downcast_ref::<&str>()
                        .map(|s| s.to_string())
                        .or_else(|| p.downcast_ref::<String>().cloned())
                        .unwrap_or_else(|| "opaque panic".into());
                    Err(anyhow::anyhow!("trial panicked: {msg}"))
                });
                if tx.send(result.map(|r| (r, i))).is_err() {
                    break;
                }
            });
        }
        drop(tx);
        for result in rx {
            // A trial that dies before producing a result is logged and left
            // unrecorded — resume retries it. One broken trial must not cost
            // the other ninety-nine.
            let (r, task_idx) = match result {
                Ok(r) => r,
                Err(e) => {
                    failed += 1;
                    eprintln!("  TRIAL ERROR (will retry on resume): {e:#}");
                    continue;
                }
            };
            let oracles: Vec<(String, bool, f64, Option<String>)> = r
                .oracles
                .iter()
                .map(|o| (o.kind.clone(), o.passed, o.weight, o.detail.clone()))
                .collect();
            store.record_trial(&TrialRecord {
                round_id,
                task_id: &r.task_id,
                attempt: r.attempt,
                outcome: r.outcome,
                telemetry: &r.telemetry,
                diff_stat: Some(&r.diff_stat),
                oracles: &oracles,
                tools: &r.tools,
                model_calls: &r.model_calls,
                started_epoch: Some(r.started_epoch),
                finished_epoch: Some(r.finished_epoch),
                rung: r.rung.as_deref(),
                steps: Some(r.steps),
                stop_reason: r.stop_reason.as_deref(),
                provenance: TrialProvenance {
                    fault: r.fault,
                    telemetry_source: r.telemetry_source,
                    proxy: r.proxy,
                    prompt_variant: r.prompt_variant,
                    task_content_sha: shas.get(task_idx).map(String::as_str),
                    session_id: Some(session),
                },
            })?;
            eprintln!(
                "  {} a{}: {} ({} oracles passed)",
                r.task_id,
                r.attempt,
                r.outcome.as_str(),
                r.oracles.iter().filter(|o| o.passed).count()
            );
        }
        Ok(())
    })?;

    store.finish_round(round_id, &now_iso())?;
    Ok(RoundOutcome { round_id, ran: total - failed, skipped, failed, no_variant })
}

fn now_epoch() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

/// Ask the harness what version it is. Best-effort: a harness with no
/// `--version` simply goes unrecorded rather than being guessed at.
fn probe_harness_version(manifest: &Manifest) -> Option<String> {
    let program = manifest.command.first()?;
    let out = std::process::Command::new(program).arg("--version").output().ok()?;
    let text = String::from_utf8_lossy(&out.stdout);
    let line = text.lines().next()?.trim();
    (!line.is_empty()).then(|| line.chars().take(80).collect())
}

fn now_iso() -> String {
    // Seconds since epoch is provenance enough; no chrono dependency.
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    format!("epoch:{secs}")
}
