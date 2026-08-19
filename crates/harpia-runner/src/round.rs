//! A round: (harness, model, effort) over the corpus, with attempts, resume,
//! and a worker pool. Workers run trials; the round loop owns the store and
//! writes each result before handing out more work.

use crate::tasks::TaskDir;
use crate::trial::{run_trial, TrialConfig, TrialResult};
use anyhow::{Context, Result};
use harpia_harness::Manifest;
use harpia_store::{Store, TrialRecord};
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
}

pub struct RoundOutcome {
    pub round_id: i64,
    pub ran: usize,
    pub skipped: usize,
    /// Trials that produced no result; unrecorded, so resume retries them.
    pub failed: usize,
}

pub fn run_round(
    store: &mut Store,
    manifest: &Manifest,
    tasks: &[TaskDir],
    cfg: &RoundConfig,
) -> Result<RoundOutcome> {
    store.upsert_harness(&manifest.id, env!("CARGO_PKG_VERSION"), &format!("{manifest:?}"))?;
    for t in tasks {
        store.upsert_task(
            &t.spec.id,
            &format!("{:?}", t.spec.stack).to_lowercase(),
            &format!("{:?}", t.spec.tier).to_lowercase(),
            &t.spec.title,
            &t.spec_toml()?,
        )?;
    }

    let round_id = match store.round_id(&cfg.label)? {
        Some(id) => id,
        None => store.begin_round(
            &cfg.label,
            &manifest.id,
            &cfg.model,
            cfg.effort.as_deref(),
            &cfg.tasks_sha,
            &now_iso(),
        )?,
    };
    let done = store.done_attempts(round_id)?;

    let sandbox_root = cfg.runs_dir.join(&cfg.label);
    std::fs::create_dir_all(&sandbox_root)?;

    // Work list: every (task, attempt) not already recorded.
    let mut work: VecDeque<(usize, u32)> = VecDeque::new();
    let mut skipped = 0usize;
    let mut failed = 0usize;
    for (i, t) in tasks.iter().enumerate() {
        for attempt in 1..=cfg.attempts {
            if done.contains(&(t.spec.id.clone(), attempt)) {
                skipped += 1;
            } else {
                work.push_back((i, attempt));
            }
        }
    }
    let total = work.len();

    let queue = Arc::new(Mutex::new(work));
    let (tx, rx) = mpsc::channel::<Result<TrialResult>>();
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
                if tx.send(result).is_err() {
                    break;
                }
            });
        }
        drop(tx);
        for result in rx {
            // A trial that dies before producing a result is logged and left
            // unrecorded — resume retries it. One broken trial must not cost
            // the other ninety-nine.
            let r = match result {
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
    Ok(RoundOutcome { round_id, ran: total - failed, skipped, failed })
}

fn now_iso() -> String {
    // Seconds since epoch is provenance enough; no chrono dependency.
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    format!("epoch:{secs}")
}
