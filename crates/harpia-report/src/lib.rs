//! Report generation: per-round scorecards and paired round-vs-round
//! comparisons. The scorecard never collapses to one number — the point of
//! a harness bench is the trade-offs a single score hides.

use anyhow::Result;
use harpia_core::metrics::Outcome;
use harpia_core::stats;
use harpia_store::{Store, TrialRow};
use serde::Serialize;
use std::collections::BTreeMap;

const CI_ITERS: u32 = 4000;
const CI_SEED: u64 = 0x4841525049_41; // "HARPIA"

#[derive(Debug, Clone, Serialize)]
pub struct Scorecard {
    pub label: String,
    pub harness: String,
    pub model: String,
    pub effort: Option<String>,
    pub tasks_sha: String,
    pub tasks: usize,
    pub trials: usize,
    /// Mean per-task capability, attempt 1 only, with 95% bootstrap CI.
    pub capability: f64,
    pub capability_ci: (f64, f64),
    pub solve_rate: f64,
    pub security: f64,
    /// Present when any task has repeats.
    pub stability: Option<f64>,
    pub outcomes: BTreeMap<String, u32>,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_read_tokens: u64,
    pub cache_write_tokens: u64,
    pub cache_hit_pct: Option<f64>,
    pub cost_usd: f64,
    pub requests: u64,
    pub tool_calls: u64,
    pub tool_errors: u64,
    pub oracle_passed: u64,
    pub oracle_total: u64,
    pub wall_hours: f64,
    pub capability_per_dollar: Option<f64>,
    pub capability_per_hour: Option<f64>,
    pub capability_per_ktok_out: Option<f64>,
}

pub fn scorecard(store: &Store, round_id: i64) -> Result<Scorecard> {
    let (label, harness, model, effort, tasks_sha) = store.round_meta(round_id)?;
    let rows = store.round_trials(round_id)?;
    let (oracle_passed, oracle_total) = store.oracle_counts(round_id)?;

    let first_attempts: Vec<&TrialRow> = rows.iter().filter(|r| r.attempt == 1).collect();
    let caps: Vec<f64> = first_attempts.iter().map(|r| r.capability).collect();
    let capability = stats::mean(&caps);
    let capability_ci =
        stats::bootstrap_ci_mean(&caps, CI_ITERS, 0.05, CI_SEED).unwrap_or((capability, capability));
    let solve_rate = if first_attempts.is_empty() {
        0.0
    } else {
        first_attempts.iter().filter(|r| r.capability >= 1.0).count() as f64
            / first_attempts.len() as f64
    };
    let secs: Vec<f64> = first_attempts.iter().map(|r| r.security).collect();

    // Stability over tasks that have repeats.
    let mut by_task: BTreeMap<&str, Vec<(f64, Outcome)>> = BTreeMap::new();
    for r in &rows {
        by_task
            .entry(r.task_id.as_str())
            .or_default()
            .push((r.capability, r.outcome));
    }
    let repeat_sets: Vec<Vec<(f64, Outcome)>> =
        by_task.values().filter(|v| v.len() > 1).cloned().collect();
    let stability = (!repeat_sets.is_empty()).then(|| harpia_core::scoring::stability(&repeat_sets));

    let mut outcomes: BTreeMap<String, u32> = BTreeMap::new();
    let mut t = harpia_core::metrics::Telemetry::default();
    let mut cost = 0.0;
    // Shadow pricing: a harness that reports no cost (wire-proxied, or on a
    // subscription) is still priced from the table so rounds stay comparable.
    let table_price = store.price(&model)?;
    for r in &rows {
        *outcomes.entry(r.outcome.as_str().to_string()).or_default() += 1;
        t.input_tokens += r.telemetry.input_tokens;
        t.output_tokens += r.telemetry.output_tokens;
        t.cache_read_tokens += r.telemetry.cache_read_tokens;
        t.cache_write_tokens += r.telemetry.cache_write_tokens;
        t.requests += r.telemetry.requests;
        t.tool_calls += r.telemetry.tool_calls;
        t.tool_errors += r.telemetry.tool_errors;
        t.wall_ms += r.telemetry.wall_ms;
        cost += match (r.telemetry.cost_usd, table_price) {
            (Some(c), _) if c > 0.0 => c,
            (_, Some(p)) => p.cost(&r.telemetry),
            (Some(c), None) => c,
            (None, None) => 0.0,
        };
    }
    let wall_hours = t.wall_ms as f64 / 3_600_000.0;

    Ok(Scorecard {
        label,
        harness,
        model,
        effort,
        tasks_sha,
        tasks: by_task.len(),
        trials: rows.len(),
        capability,
        capability_ci,
        solve_rate,
        security: stats::mean(&secs),
        stability,
        outcomes,
        input_tokens: t.input_tokens,
        output_tokens: t.output_tokens,
        cache_read_tokens: t.cache_read_tokens,
        cache_write_tokens: t.cache_write_tokens,
        cache_hit_pct: t.cache_hit_ratio().map(|x| x * 100.0),
        cost_usd: cost,
        requests: t.requests,
        tool_calls: t.tool_calls,
        tool_errors: t.tool_errors,
        oracle_passed,
        oracle_total,
        wall_hours,
        capability_per_dollar: (cost > 0.0).then(|| capability / cost),
        capability_per_hour: (wall_hours > 0.0).then(|| capability / wall_hours),
        capability_per_ktok_out: (t.output_tokens > 0)
            .then(|| capability / (t.output_tokens as f64 / 1000.0)),
    })
}

#[derive(Debug, Clone, Serialize)]
pub struct Comparison {
    pub a: Scorecard,
    pub b: Scorecard,
    /// Tasks present with attempt 1 in both rounds.
    pub paired_tasks: usize,
    pub a_only_solved: u32,
    pub b_only_solved: u32,
    pub mcnemar_p: f64,
    /// On per-task capability differences (b - a).
    pub wilcoxon_p: Option<f64>,
    pub capability_diff: f64,
}

pub fn compare(store: &Store, round_a: i64, round_b: i64) -> Result<Comparison> {
    let a = scorecard(store, round_a)?;
    let b = scorecard(store, round_b)?;
    let rows_a = store.round_trials(round_a)?;
    let rows_b = store.round_trials(round_b)?;
    let map_a: BTreeMap<&str, &TrialRow> = rows_a
        .iter()
        .filter(|r| r.attempt == 1)
        .map(|r| (r.task_id.as_str(), r))
        .collect();
    let mut diffs = Vec::new();
    let (mut a_only, mut b_only) = (0u32, 0u32);
    let mut paired = 0usize;
    for rb in rows_b.iter().filter(|r| r.attempt == 1) {
        let Some(ra) = map_a.get(rb.task_id.as_str()) else { continue };
        paired += 1;
        diffs.push(rb.capability - ra.capability);
        let (sa, sb) = (ra.capability >= 1.0, rb.capability >= 1.0);
        match (sa, sb) {
            (true, false) => a_only += 1,
            (false, true) => b_only += 1,
            _ => {}
        }
    }
    Ok(Comparison {
        a,
        b,
        paired_tasks: paired,
        a_only_solved: a_only,
        b_only_solved: b_only,
        mcnemar_p: stats::mcnemar_p(a_only, b_only),
        wilcoxon_p: stats::wilcoxon_p(&diffs),
        capability_diff: stats::mean(&diffs),
    })
}

pub fn render_text(s: &Scorecard) -> String {
    let mut o = String::new();
    let push = |o: &mut String, line: String| {
        o.push_str(&line);
        o.push('\n');
    };
    push(&mut o, format!("round      {}  ({} + {}{})", s.label, s.harness, s.model,
        s.effort.as_deref().map(|e| format!(" @{e}")).unwrap_or_default()));
    push(&mut o, format!("corpus     {} tasks, {} trials, sha {}", s.tasks, s.trials, s.tasks_sha));
    push(&mut o, format!("capability {:.3}  [{:.3}, {:.3}]  solve {:.0}%",
        s.capability, s.capability_ci.0, s.capability_ci.1, s.solve_rate * 100.0));
    push(&mut o, format!("security   {:.3}", s.security));
    if let Some(st) = s.stability {
        push(&mut o, format!("stability  {st:.3}"));
    }
    push(&mut o, format!("outcomes   {:?}", s.outcomes));
    push(&mut o, format!("oracles    {}/{}", s.oracle_passed, s.oracle_total));
    push(&mut o, format!("tokens     in {}  out {}  cache-read {}  cache-write {}",
        s.input_tokens, s.output_tokens, s.cache_read_tokens, s.cache_write_tokens));
    if let Some(pct) = s.cache_hit_pct {
        push(&mut o, format!("cache-hit  {pct:.1}%"));
    }
    push(&mut o, format!("cost       ${:.4}   requests {}   tools {} ({} errors)",
        s.cost_usd, s.requests, s.tool_calls, s.tool_errors));
    push(&mut o, format!("wall       {:.2} h", s.wall_hours));
    o
}

pub fn render_compare_text(c: &Comparison) -> String {
    let mut o = String::new();
    o.push_str(&format!("A: {}\n", render_text(&c.a).replace('\n', "\n   ")));
    o.push_str(&format!("B: {}\n", render_text(&c.b).replace('\n', "\n   ")));
    o.push_str(&format!(
        "paired     {} tasks  |  solved only by A: {}  only by B: {}  (McNemar p = {:.4})\n",
        c.paired_tasks, c.a_only_solved, c.b_only_solved, c.mcnemar_p
    ));
    o.push_str(&format!(
        "capability B - A = {:+.3}  (Wilcoxon p = {})\n",
        c.capability_diff,
        c.wilcoxon_p.map(|p| format!("{p:.4}")).unwrap_or_else(|| "n/a".into())
    ));
    o
}

#[cfg(test)]
mod tests {
    use super::*;
    use harpia_core::metrics::{Outcome, Telemetry};
    use harpia_store::TrialRecord;

    fn record(store: &mut Store, round: i64, task: &str, attempt: u32, solved: bool) {
        let t = Telemetry {
            input_tokens: 100,
            output_tokens: 50,
            cache_read_tokens: 300,
            requests: 2,
            tool_calls: 3,
            wall_ms: 60_000,
            cost_usd: Some(0.01),
            ..Default::default()
        };
        store
            .record_trial(&TrialRecord {
                round_id: round,
                task_id: task,
                attempt,
                outcome: Outcome::Finished,
                telemetry: &t,
                diff_stat: None,
                oracles: &[
                    ("hidden-tests".into(), solved, 1.0, None),
                    ("security".into(), true, 1.0, None),
                ],
                tools: &[],
            })
            .unwrap();
    }

    fn seeded() -> (Store, i64, i64) {
        let mut s = Store::open_in_memory().unwrap();
        s.upsert_harness("ha", "0", "").unwrap();
        s.upsert_harness("hb", "0", "").unwrap();
        for t in ["t1", "t2", "t3", "t4", "t5", "t6", "t7", "t8"] {
            s.upsert_task(t, "rust", "simple", t, "").unwrap();
        }
        let ra = s.begin_round("round-a", "ha", "m", None, "sha", "now").unwrap();
        let rb = s.begin_round("round-b", "hb", "m", None, "sha", "now").unwrap();
        // A solves t1-t2; B solves t1-t6. Repeats on t1 for stability.
        for (i, t) in ["t1", "t2", "t3", "t4", "t5", "t6", "t7", "t8"].iter().enumerate() {
            record(&mut s, ra, t, 1, i < 2);
            record(&mut s, rb, t, 1, i < 6);
        }
        record(&mut s, ra, "t1", 2, true);
        record(&mut s, ra, "t1", 3, true);
        (s, ra, rb)
    }

    #[test]
    fn scorecard_aggregates() {
        let (s, ra, _) = seeded();
        let card = scorecard(&s, ra).unwrap();
        assert_eq!(card.tasks, 8);
        assert_eq!(card.trials, 10);
        assert!((card.capability - 0.25).abs() < 1e-12);
        assert!(card.capability_ci.0 <= 0.25 && 0.25 <= card.capability_ci.1);
        assert_eq!(card.security, 1.0);
        let st = card.stability.expect("t1 has repeats");
        assert!(st > 0.9, "identical repeats should be stable, got {st}");
        assert_eq!(card.oracle_total, 20);
        assert!((card.cache_hit_pct.unwrap() - 75.0).abs() < 1e-9);
        assert!((card.cost_usd - 0.10).abs() < 1e-9);
    }

    #[test]
    fn compare_is_paired_and_directional() {
        let (s, ra, rb) = seeded();
        let c = compare(&s, ra, rb).unwrap();
        assert_eq!(c.paired_tasks, 8);
        assert_eq!(c.a_only_solved, 0);
        assert_eq!(c.b_only_solved, 4);
        assert!((c.capability_diff - 0.5).abs() < 1e-12);
        assert!(c.mcnemar_p < 0.2, "4:0 discordant, p = {}", c.mcnemar_p);
        let text = render_compare_text(&c);
        assert!(text.contains("only by B: 4"));
    }
}
