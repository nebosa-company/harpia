use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use harpia_harness::Manifest;
use harpia_runner::round::{run_round, RoundConfig};
use harpia_runner::tasks::load_tasks;
use harpia_runner::validate::{validate_task, STARTER_FLOOR};
use harpia_runner::{audit, contamination, toolchain};
use harpia_store::meta::{AuditRow, ContaminationRow, CorpusCheckRow};
use harpia_store::{Price, Store};
use serde::Deserialize;
use std::path::PathBuf;
use std::time::Duration;

#[derive(Deserialize)]
struct PriceEntry {
    input_per_mtok: f64,
    output_per_mtok: f64,
    #[serde(default)]
    cache_read_per_mtok: f64,
    #[serde(default)]
    cache_write_per_mtok: f64,
}

/// Seed the price table from `prices.toml` beside the harnesses dir.
fn seed_prices(store: &Store, harnesses: &std::path::Path) -> Result<()> {
    let path = harnesses
        .parent()
        .unwrap_or_else(|| std::path::Path::new("."))
        .join("prices.toml");
    let Ok(raw) = std::fs::read_to_string(&path) else { return Ok(()) };
    let table: std::collections::BTreeMap<String, PriceEntry> =
        toml::from_str(&raw).with_context(|| format!("parsing {}", path.display()))?;
    for (model, p) in table {
        store.set_price(
            &model,
            Price {
                input_per_mtok: p.input_per_mtok,
                output_per_mtok: p.output_per_mtok,
                cache_read_per_mtok: p.cache_read_per_mtok,
                cache_write_per_mtok: p.cache_write_per_mtok,
            },
        )?;
    }
    Ok(())
}

#[derive(Parser)]
#[command(name = "harpia", version, about = "Agentic harness benchmark")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

// Clap owns one of these per process; the size spread between `Run` and
// `Drift` costs nothing worth boxing for.
#[allow(clippy::large_enum_variant)]
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
        /// Prompt wording to use. 0 is canonical; higher values need the task
        /// to define `prompt_variants`, and tasks that do not are left
        /// unmeasured rather than run with the canonical text.
        #[arg(long, default_value_t = 0)]
        prompt_variant: u32,
        /// Multiply every task's wall-clock and cost ceiling. Run the same
        /// harness at 1.0 and 2.0 to see how much of its score was the budget.
        #[arg(long, default_value_t = 1.0)]
        budget_scale: f64,
        /// Calibration arm: put the hidden tests in the workspace before the
        /// harness runs. Never a scoring round.
        #[arg(long)]
        oracles_visible: bool,
        /// Shuffle the task order with this seed, to test order effects.
        #[arg(long)]
        order_seed: Option<u64>,
        #[arg(long)]
        notes: Option<String>,
    },
    /// Validate the corpus: reference solutions pass, starters fail.
    Validate {
        #[arg(long, default_value = "tasks")]
        tasks: PathBuf,
        #[arg(long, default_value_t = 600)]
        oracle_timeout: u64,
        #[arg(long)]
        filter: Option<String>,
        /// Record this sweep in the database, so the next one can be diffed
        /// against it and toolchain drift shows up as drift.
        #[arg(long)]
        record: bool,
        #[arg(long, default_value = "harpia.db")]
        db: PathBuf,
    },
    /// Render a round's scorecard.
    Report {
        #[arg(long)]
        label: String,
        #[arg(long, default_value = "harpia.db")]
        db: PathBuf,
        #[arg(long)]
        json: bool,
    },
    /// Meta-evaluation: is the benchmark itself sound?
    ///
    /// Item quality and reliability, bootstrap rank stability, leave-one-out
    /// by stack and tier, scoring-rule sensitivity, repeat agreement, paired
    /// power, instrumentation integrity, budget exposure, oracle validity,
    /// corpus drift and contamination -- in one report.
    Robustness {
        #[arg(long, default_value = "harpia.db")]
        db: PathBuf,
        /// Round labels to include; default is every round in the database.
        #[arg(long, value_delimiter = ',')]
        rounds: Vec<String>,
        #[arg(long, default_value_t = 4000)]
        iters: u32,
        #[arg(long, default_value_t = 0x4841_5250_4941)]
        seed: u64,
        #[arg(long)]
        json: bool,
    },
    /// Audit the oracles themselves: break each reference solution and check
    /// the oracles notice; rewrite it harmlessly and check they do not.
    Audit {
        #[arg(long, default_value = "tasks")]
        tasks: PathBuf,
        #[arg(long, default_value = "harpia.db")]
        db: PathBuf,
        #[arg(long)]
        filter: Option<String>,
        /// Audit only every Nth task -- a full sweep compiles the corpus many
        /// times over.
        #[arg(long, default_value_t = 1)]
        stride: usize,
        #[arg(long, default_value_t = 1)]
        jobs: usize,
        #[arg(long, default_value_t = 600)]
        oracle_timeout: u64,
        /// Print results without writing them to the database.
        #[arg(long)]
        dry_run: bool,
    },
    /// Contamination sweep: canary uniqueness, and shingle overlap against an
    /// external corpus and against the rest of Harpia.
    Contamination {
        #[arg(long, default_value = "tasks")]
        tasks: PathBuf,
        #[arg(long, default_value = "harpia.db")]
        db: PathBuf,
        /// Directory of external text to compare against (public benchmarks,
        /// a training-data sample, anything).
        #[arg(long)]
        against: Option<PathBuf>,
        #[arg(long, default_value = "external")]
        label: String,
        #[arg(long)]
        json: bool,
    },
    /// Corpus drift: what changed between the last two validation sweeps.
    Drift {
        #[arg(long, default_value = "harpia.db")]
        db: PathBuf,
        #[arg(long)]
        json: bool,
    },
    /// Paired statistical comparison of two rounds.
    Compare {
        #[arg(long)]
        a: String,
        #[arg(long)]
        b: String,
        #[arg(long, default_value = "harpia.db")]
        db: PathBuf,
        #[arg(long)]
        json: bool,
    },
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
            prompt_variant,
            budget_scale,
            oracles_visible,
            order_seed,
            notes,
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
            seed_prices(&store, &harnesses)?;
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
                    prompt_variant,
                    budget_scale,
                    oracles_visible,
                    order_seed,
                    notes,
                },
            )?;
            eprintln!(
                "round #{}: ran {}, resumed past {}, errored {}, unmeasured (no such wording) {}",
                out.round_id, out.ran, out.skipped, out.failed, out.no_variant
            );
            if out.failed > 0 {
                eprintln!("errored trials are unrecorded; re-run the same label to retry them");
                std::process::exit(3);
            }
            Ok(())
        }
        Cmd::Validate { tasks, oracle_timeout, filter, record, db } => {
            let mut corpus = load_tasks(&tasks)?;
            if let Some(f) = &filter {
                corpus.retain(|t| t.spec.id.contains(f.as_str()));
            }
            let scratch = std::env::temp_dir().join("harpia-validate");
            let store = record.then(|| Store::open(&db)).transpose()?;
            let toolchain = toolchain::probe_json();
            let at = now_epoch();
            let mut bad = 0usize;
            let mut marginal = 0usize;
            for task in &corpus {
                let v = validate_task(task, &scratch, Duration::from_secs(oracle_timeout))?;
                let verdict = if v.ok() { "ok  " } else { "FAIL" };
                if !v.ok() {
                    bad += 1;
                }
                if v.marginal() {
                    marginal += 1;
                }
                println!(
                    "{verdict} {:<28} solution {:.2}  starter {:.2}  margin {:.3}{}",
                    v.task_id,
                    v.solution_capability,
                    v.starter_capability,
                    v.starter_margin(),
                    if v.marginal() { "  MARGINAL" } else { "" }
                );
                if let Some(store) = &store {
                    store.record_corpus_check(&CorpusCheckRow {
                        at_epoch: at,
                        task_id: v.task_id.clone(),
                        content_sha: v.content_sha.clone(),
                        solution_capability: v.solution_capability,
                        starter_capability: v.starter_capability,
                        ok: v.ok(),
                        toolchain: Some(toolchain.clone()),
                    })?;
                }
            }
            println!(
                "{} of {} tasks valid (solution = 1.00, starter <= {STARTER_FLOOR}); {marginal} within a third of the floor",
                corpus.len() - bad,
                corpus.len()
            );
            if store.is_some() {
                println!("sweep recorded at epoch {at}; `harpia drift` compares it to the previous one");
            }
            if bad > 0 {
                std::process::exit(1);
            }
            Ok(())
        }
        Cmd::Robustness { db, rounds, iters, seed, json } => {
            let store = Store::open(&db)?;
            let mut ids = Vec::new();
            for label in &rounds {
                ids.push(
                    store
                        .round_id(label)?
                        .with_context(|| format!("no round labelled `{label}`"))?,
                );
            }
            let cfg = harpia_report::meta::MetaConfig { iters, seed, ..Default::default() };
            let report = harpia_report::meta::robustness(&store, &ids, &cfg)?;
            if json {
                println!("{}", serde_json::to_string_pretty(&report)?);
            } else {
                print!("{}", harpia_report::meta::render_text(&report));
            }
            Ok(())
        }
        Cmd::Audit { tasks, db, filter, stride, jobs, oracle_timeout, dry_run } => {
            let mut corpus = load_tasks(&tasks)?;
            if let Some(f) = &filter {
                corpus.retain(|t| t.spec.id.contains(f.as_str()));
            }
            if stride > 1 {
                let mut i = 0;
                corpus.retain(|_| {
                    i += 1;
                    (i - 1) % stride == 0
                });
            }
            if corpus.is_empty() {
                bail!("no tasks matched");
            }
            eprintln!("auditing oracles of {} task(s) with {jobs} job(s)", corpus.len());
            let cfg = audit::AuditConfig {
                scratch: std::env::temp_dir().join("harpia-audit"),
                timeout: Duration::from_secs(oracle_timeout),
            };
            let rows = audit::audit_corpus(&corpus, &cfg, jobs);
            let mutants: Vec<_> = rows
                .iter()
                .filter(|r| r.kind == audit::AuditKind::Mutation)
                .collect();
            let invariants: Vec<_> = rows
                .iter()
                .filter(|r| r.kind == audit::AuditKind::Metamorphic)
                .collect();
            let caught = mutants.iter().filter(|r| r.passed).count();
            let held = invariants.iter().filter(|r| r.passed).count();
            println!(
                "mutation score {caught}/{} ({:.1}%) -- surviving mutants are oracles that accept broken code",
                mutants.len(),
                100.0 * caught as f64 / mutants.len().max(1) as f64
            );
            println!(
                "invariance     {held}/{} ({:.1}%) -- failures are oracles that reject correct code",
                invariants.len(),
                100.0 * held as f64 / invariants.len().max(1) as f64
            );
            for r in rows.iter().filter(|r| !r.passed) {
                println!(
                    "  {:<28} {:<12} {:<16} observed {:.2}  {}",
                    r.task_id,
                    r.kind.as_str(),
                    r.operator,
                    r.observed,
                    r.detail.clone().unwrap_or_default()
                );
            }
            if !dry_run {
                let store = Store::open(&db)?;
                let at = now_epoch();
                for task in &corpus {
                    store.upsert_task(
                        &task.spec.id,
                        &format!("{:?}", task.spec.stack).to_lowercase(),
                        &format!("{:?}", task.spec.tier).to_lowercase(),
                        &task.spec.title,
                        &task.spec_toml()?,
                    )?;
                }
                for r in &rows {
                    store.record_oracle_audit(&AuditRow {
                        at_epoch: at,
                        task_id: r.task_id.clone(),
                        content_sha: None,
                        kind: r.kind.as_str().to_string(),
                        operator: r.operator.clone(),
                        target: r.target.clone(),
                        expected: if r.expected_pass { "pass".into() } else { "fail".into() },
                        observed: if r.observed.is_finite() { r.observed } else { -1.0 },
                        passed: r.passed,
                        detail: r.detail.clone(),
                    })?;
                }
                println!("{} audit rows recorded", rows.len());
            }
            Ok(())
        }
        Cmd::Contamination { tasks, db, against, label, json } => {
            let corpus = load_tasks(&tasks)?;
            let findings = contamination::scan(&corpus, against.as_deref(), &label)?;
            if json {
                let rows: Vec<_> = findings
                    .iter()
                    .map(|f| {
                        serde_json::json!({
                            "task_id": f.task_id,
                            "canary": f.canary,
                            "canary_unique": f.canary_unique,
                            "max_similarity": f.max_similarity,
                            "nearest_source": f.nearest_source,
                            "corpus_label": f.corpus_label,
                        })
                    })
                    .collect();
                println!("{}", serde_json::to_string_pretty(&rows)?);
            } else {
                let with = findings.iter().filter(|f| f.canary.is_some()).count();
                let unique = findings.iter().filter(|f| f.canary_unique == Some(true)).count();
                println!("{} tasks, {with} with a canary, {unique} of those unique", findings.len());
                let mut worst = findings.clone();
                worst.sort_by(|a, b| b.max_similarity.total_cmp(&a.max_similarity));
                for f in worst.iter().take(15) {
                    println!(
                        "  {:<30} {:.3} vs {} [{}]",
                        f.task_id,
                        f.max_similarity,
                        f.nearest_source.clone().unwrap_or_else(|| "-".into()),
                        f.corpus_label
                    );
                }
                for f in findings.iter().filter(|f| f.canary_unique == Some(false)) {
                    println!("  CANARY NOT UNIQUE: {}", f.task_id);
                }
            }
            let store = Store::open(&db)?;
            let at = now_epoch();
            for f in &findings {
                store.record_contamination(&ContaminationRow {
                    task_id: f.task_id.clone(),
                    at_epoch: at,
                    canary: f.canary.clone(),
                    canary_unique: f.canary_unique,
                    max_similarity: Some(f.max_similarity),
                    nearest_source: f.nearest_source.clone(),
                    corpus_label: Some(f.corpus_label.clone()),
                })?;
            }
            Ok(())
        }
        Cmd::Drift { db, json } => {
            let store = Store::open(&db)?;
            let report = harpia_report::meta::robustness(
                &store,
                &[],
                &harpia_report::meta::MetaConfig { iters: 1, ..Default::default() },
            )?;
            match report.drift {
                None => {
                    println!("fewer than two recorded validation sweeps; run `harpia validate --record` twice");
                }
                Some(d) if json => println!("{}", serde_json::to_string_pretty(&d)?),
                Some(d) => {
                    println!(
                        "between sweeps {} and {}: {} newly failing, {} newly passing, {} edited",
                        d.previous_epoch,
                        d.latest_epoch,
                        d.newly_failing.len(),
                        d.newly_passing.len(),
                        d.content_changed.len()
                    );
                    for t in &d.newly_failing {
                        println!("  now failing: {t}");
                    }
                    for (tool, before, after) in &d.toolchain_changes {
                        println!(
                            "  toolchain {tool}: {} -> {}",
                            before.clone().unwrap_or_else(|| "absent".into()),
                            after.clone().unwrap_or_else(|| "absent".into())
                        );
                    }
                    for (task, starter) in &d.marginal_tasks {
                        println!("  marginal: {task} starter {starter:.3}");
                    }
                }
            }
            Ok(())
        }
        Cmd::Report { label, db, json } => {
            let store = Store::open(&db)?;
            let id = store
                .round_id(&label)?
                .with_context(|| format!("no round labelled `{label}`"))?;
            let card = harpia_report::scorecard(&store, id)?;
            if json {
                println!("{}", serde_json::to_string_pretty(&card)?);
            } else {
                print!("{}", harpia_report::render_text(&card));
            }
            Ok(())
        }
        Cmd::Compare { a, b, db, json } => {
            let store = Store::open(&db)?;
            let ia = store.round_id(&a)?.with_context(|| format!("no round `{a}`"))?;
            let ib = store.round_id(&b)?.with_context(|| format!("no round `{b}`"))?;
            let cmp = harpia_report::compare(&store, ia, ib)?;
            if json {
                println!("{}", serde_json::to_string_pretty(&cmp)?);
            } else {
                print!("{}", harpia_report::render_compare_text(&cmp));
            }
            Ok(())
        }
    }
}

fn now_epoch() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
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
