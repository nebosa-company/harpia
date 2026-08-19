use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use harpia_harness::Manifest;
use harpia_runner::round::{run_round, RoundConfig};
use harpia_runner::tasks::load_tasks;
use harpia_runner::validate::{validate_task, STARTER_FLOOR};
use harpia_store::Store;
use std::path::PathBuf;
use std::time::Duration;

#[derive(Parser)]
#[command(name = "harpia", version, about = "Agentic harness benchmark")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Run (or resume) a benchmark round: a harness+model over the corpus.
    Run {
        #[arg(long)]
        harness: String,
        #[arg(long)]
        model: String,
        #[arg(long)]
        label: String,
        #[arg(long)]
        effort: Option<String>,
        #[arg(long, default_value = "tasks")]
        tasks: PathBuf,
        #[arg(long, default_value = "harnesses")]
        harnesses: PathBuf,
        #[arg(long, default_value = "harpia.db")]
        db: PathBuf,
        #[arg(long, default_value = "runs")]
        runs: PathBuf,
        #[arg(long, default_value_t = 1)]
        attempts: u32,
        #[arg(long, default_value_t = 1)]
        jobs: usize,
        /// Keep every trial sandbox on disk (debugging).
        #[arg(long)]
        keep_sandbox: bool,
        #[arg(long, default_value_t = 600)]
        oracle_timeout: u64,
        /// Only run task ids containing this substring.
        #[arg(long)]
        filter: Option<String>,
    },
    /// Validate the corpus: reference solutions pass, starters fail.
    Validate {
        #[arg(long, default_value = "tasks")]
        tasks: PathBuf,
        #[arg(long, default_value_t = 600)]
        oracle_timeout: u64,
        #[arg(long)]
        filter: Option<String>,
    },
    /// Render a round's scorecard.
    Report,
    /// Paired statistical comparison of two rounds.
    Compare,
}

fn main() -> Result<()> {
    match Cli::parse().cmd {
        Cmd::Run {
            harness,
            model,
            label,
            effort,
            tasks,
            harnesses,
            db,
            runs,
            attempts,
            jobs,
            keep_sandbox,
            oracle_timeout,
            filter,
        } => {
            let manifests = Manifest::load_dir(&harnesses)?;
            let manifest = manifests
                .get(&harness)
                .with_context(|| format!("no harness `{harness}` in {}", harnesses.display()))?;
            let mut corpus = load_tasks(&tasks)?;
            if let Some(f) = &filter {
                corpus.retain(|t| t.spec.id.contains(f.as_str()));
            }
            if corpus.is_empty() {
                bail!("no tasks matched");
            }
            let tasks_sha = git_sha(&tasks);
            let mut store = Store::open(&db)?;
            eprintln!(
                "round `{label}`: {} × {model} over {} tasks × {attempts} attempt(s), {jobs} job(s)",
                manifest.id,
                corpus.len()
            );
            let out = run_round(
                &mut store,
                manifest,
                &corpus,
                &RoundConfig {
                    label,
                    model,
                    effort,
                    tasks_sha,
                    attempts,
                    jobs,
                    runs_dir: runs,
                    keep_sandbox,
                    oracle_timeout_secs: oracle_timeout,
                },
            )?;
            eprintln!("round #{}: ran {}, resumed past {}", out.round_id, out.ran, out.skipped);
            Ok(())
        }
        Cmd::Validate { tasks, oracle_timeout, filter } => {
            let mut corpus = load_tasks(&tasks)?;
            if let Some(f) = &filter {
                corpus.retain(|t| t.spec.id.contains(f.as_str()));
            }
            let scratch = std::env::temp_dir().join("harpia-validate");
            let mut bad = 0usize;
            for task in &corpus {
                let v = validate_task(task, &scratch, Duration::from_secs(oracle_timeout))?;
                let verdict = if v.ok() { "ok " } else { "FAIL" };
                if !v.ok() {
                    bad += 1;
                }
                println!(
                    "{verdict} {:<28} solution {:.2}  starter {:.2}",
                    v.task_id, v.solution_capability, v.starter_capability
                );
            }
            println!(
                "{} of {} tasks valid (solution = 1.00, starter <= {STARTER_FLOOR})",
                corpus.len() - bad,
                corpus.len()
            );
            if bad > 0 {
                std::process::exit(1);
            }
            Ok(())
        }
        Cmd::Report | Cmd::Compare => {
            eprintln!("report/compare land with harpia-report");
            std::process::exit(2);
        }
    }
}

fn git_sha(tasks_dir: &PathBuf) -> String {
    std::process::Command::new("git")
        .args(["-C"])
        .arg(tasks_dir)
        .args(["rev-parse", "--short", "HEAD"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|| "uncommitted".into())
}
