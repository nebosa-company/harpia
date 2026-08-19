// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//! The report about the benchmark.
//!
//! `scorecard` says how a harness did. This module asks whether the
//! benchmark was in a position to say so: are the items still informative,
//! does the ranking survive resampling and re-weighting, do repeats agree,
//! is the gap larger than what this many tasks can resolve, did the
//! accounting actually get measured, and were the two rounds even run
//! against the same bytes.
//!
//! Nothing here is derived from the headline capability alone. Alternative
//! scoring rules are recomputed from the stored oracle verdicts, because a
//! stored score already contains the weighting under test.

use anyhow::Result;
use harpia_core::matrix::ScoreMatrix;
use harpia_core::metrics::{Fault, Outcome, TelemetrySource};
use harpia_core::psychometrics::{self, ItemAnalysis, ItemStat};
use harpia_core::robustness::{self, GroupDrop, ItemInfluence, RankStability, RuleRanking};
use harpia_core::stats::{self, VarianceComponents};
use harpia_store::meta::RoundRow;
use harpia_store::Store;
use serde::Serialize;
use std::collections::{BTreeMap, BTreeSet};

pub struct MetaConfig {
    pub iters: u32,
    pub seed: u64,
    pub alpha: f64,
    pub power: f64,
    /// How many worst-offender rows each section prints.
    pub top_n: usize,
}

impl Default for MetaConfig {
    fn default() -> Self {
        Self { iters: 4000, seed: 0x4841_5250_4941, alpha: 0.05, power: 0.8, top_n: 8 }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct RoundSummary {
    pub label: String,
    pub harness: String,
    pub model: String,
    pub effort: Option<String>,
    pub tasks: usize,
    pub capability: f64,
    pub budget_scale: f64,
    pub prompt_variant: u32,
    pub oracles_visible: bool,
    pub jobs: Option<u32>,
    pub order_seed: Option<i64>,
    pub tasks_sha: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct Reproducibility {
    pub round: String,
    /// Tasks with more than one attempt.
    pub repeat_tasks: usize,
    /// Share of those whose attempts disagreed about solved/not.
    pub flake_rate: f64,
    /// Tasks that flapped, worst first.
    pub flaky_tasks: Vec<String>,
    /// Test-retest reliability over the repeats.
    pub icc: Option<f64>,
    pub mean_within_sd: f64,
    pub pass_at_1: f64,
    pub pass_at_k: f64,
    pub k: u32,
}

#[derive(Debug, Clone, Serialize)]
pub struct Integrity {
    pub round: String,
    pub trials: usize,
    pub zero_tokens: usize,
    pub zero_requests: usize,
    pub null_cost: usize,
    pub malformed: usize,
    pub source_counts: BTreeMap<String, usize>,
    /// Trials measured twice, independently.
    pub cross_checked: usize,
    pub disagreement_mean: Option<f64>,
    pub disagreement_max: Option<f64>,
    /// Harness-reported cost against the price table, where both exist.
    pub cost_reconciled: usize,
    pub cost_mape: Option<f64>,
    pub infra_trials: usize,
    pub infra_rate: f64,
    pub infra_ci: Option<(f64, f64)>,
    /// Capability recomputed with infra-fault trials removed.
    pub capability_excl_infra: Option<f64>,
}

impl Integrity {
    /// Every usage number this round reports is measured, not assumed.
    pub fn complete(&self) -> bool {
        self.zero_tokens == 0 && self.zero_requests == 0 && self.null_cost == 0
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct BudgetExposure {
    pub round: String,
    pub trials: usize,
    pub timeouts: usize,
    pub cost_ceilings: usize,
    pub budget_bound_share: f64,
    /// Mean capability of trials that hit a ceiling. High values mean the
    /// ceiling, not the harness, ended the work.
    pub capability_when_bound: f64,
    pub budget_scale: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct SessionEffect {
    pub round: String,
    pub sessions: Vec<(String, usize, f64)>,
    /// Largest capability gap between two sessions of the same round.
    pub max_gap: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct PairPower {
    pub a: String,
    pub b: String,
    pub paired: usize,
    pub verified: usize,
    pub unverified: usize,
    pub mismatched: usize,
    pub diff: f64,
    pub ci: Option<(f64, f64)>,
    pub sd_diff: f64,
    pub mde: Option<f64>,
    pub power: Option<f64>,
    pub mcnemar_p: f64,
    pub wilcoxon_p: Option<f64>,
    pub underpowered: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct OracleAuditSummary {
    pub tasks_audited: usize,
    pub mutation_total: usize,
    pub mutation_caught: usize,
    pub mutation_score: f64,
    pub mutation_ci: Option<(f64, f64)>,
    /// (task, operator) pairs whose mutant the oracles accepted.
    pub survivors: Vec<(String, String)>,
    pub metamorphic_total: usize,
    pub metamorphic_held: usize,
    pub invariance: f64,
    pub invariance_ci: Option<(f64, f64)>,
    /// (task, operator) pairs where an unchanged-behaviour rewrite failed.
    pub false_fails: Vec<(String, String)>,
    /// Tasks the mutation operators could not touch — no applicable site in
    /// the reference solution. Their oracles are *unaudited*, which is not
    /// the same as sound, and they are named rather than averaged away.
    pub tasks_without_mutants: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct DriftSummary {
    pub previous_epoch: i64,
    pub latest_epoch: i64,
    pub newly_failing: Vec<String>,
    pub newly_passing: Vec<String>,
    pub content_changed: Vec<String>,
    pub toolchain_changes: Vec<(String, Option<String>, Option<String>)>,
    pub marginal_tasks: Vec<(String, f64)>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ContaminationSummary {
    pub tasks: usize,
    pub with_canary: usize,
    pub unique_canaries: usize,
    pub similarity_p50: f64,
    pub similarity_p95: f64,
    pub similarity_max: f64,
    pub worst: Vec<(String, f64, String)>,
}

#[derive(Debug, Clone, Serialize)]
pub struct RobustnessReport {
    pub rounds: Vec<RoundSummary>,
    pub items: ItemAnalysis,
    pub dead_items: Vec<String>,
    pub negative_items: Vec<ItemStat>,
    pub rank: Option<RankStability>,
    pub group_drops: BTreeMap<String, Vec<GroupDrop>>,
    pub influence: Vec<ItemInfluence>,
    pub rules: Vec<RuleRanking>,
    pub variance: Option<VarianceComponents>,
    pub reproducibility: Vec<Reproducibility>,
    pub pairs: Vec<PairPower>,
    pub integrity: Vec<Integrity>,
    pub budget: Vec<BudgetExposure>,
    pub sessions: Vec<SessionEffect>,
    pub oracle_audit: Option<OracleAuditSummary>,
    pub drift: Option<DriftSummary>,
    pub contamination: Option<ContaminationSummary>,
}

/// Build the whole meta-evaluation over the given rounds.
pub fn robustness(store: &Store, round_ids: &[i64], cfg: &MetaConfig) -> Result<RobustnessReport> {
    let all_rounds = store.rounds()?;
    let rounds: Vec<RoundRow> = all_rounds
        .into_iter()
        .filter(|r| round_ids.is_empty() || round_ids.contains(&r.id))
        .collect();
    let tasks = store.tasks()?;
    let stack_of: BTreeMap<String, String> =
        tasks.iter().map(|t| (t.id.clone(), t.stack.clone())).collect();
    let tier_of: BTreeMap<String, String> =
        tasks.iter().map(|t| (t.id.clone(), t.tier.clone())).collect();
    let family_of: BTreeMap<String, String> = tasks
        .iter()
        .filter_map(|t| t.family.clone().map(|f| (t.id.clone(), f)))
        .collect();

    // Three score matrices, one per aggregation rule, all rebuilt from the
    // stored oracle verdicts rather than from the stored capability.
    let mut weighted = Vec::new();
    let mut uniform = Vec::new();
    let mut strict = Vec::new();
    let mut summaries = Vec::new();
    let mut reproducibility = Vec::new();
    let mut integrity = Vec::new();
    let mut budget = Vec::new();
    let mut sessions = Vec::new();

    for round in &rounds {
        let rows = store.round_trials(round.id)?;
        let oracles = store.round_oracles(round.id)?;
        let meta = store.trial_meta(round.id)?;

        for t in oracles.iter().filter(|t| t.attempt == 1) {
            let non_sec: Vec<&harpia_store::meta::OracleVerdictRow> =
                t.verdicts.iter().filter(|v| v.kind != "security").collect();
            if non_sec.is_empty() {
                continue;
            }
            let w_num: f64 = non_sec.iter().filter(|v| v.passed).map(|v| v.weight).sum();
            let w_den: f64 = non_sec.iter().map(|v| v.weight).sum();
            let key = (round.label.clone(), t.task_id.clone());
            weighted.push((key.0.clone(), key.1.clone(), if w_den > 0.0 { w_num / w_den } else { 0.0 }));
            uniform.push((
                key.0.clone(),
                key.1.clone(),
                non_sec.iter().filter(|v| v.passed).count() as f64 / non_sec.len() as f64,
            ));
            strict.push((
                key.0,
                key.1,
                if non_sec.iter().all(|v| v.passed) { 1.0 } else { 0.0 },
            ));
        }

        let firsts: Vec<_> = rows.iter().filter(|r| r.attempt == 1).collect();
        let caps: Vec<f64> = firsts.iter().map(|r| r.capability).collect();
        summaries.push(RoundSummary {
            label: round.label.clone(),
            harness: round.harness_id.clone(),
            model: round.model.clone(),
            effort: round.effort.clone(),
            tasks: firsts.len(),
            capability: stats::mean(&caps),
            budget_scale: round.budget_scale_or_default(),
            prompt_variant: round.prompt_variant.unwrap_or(0),
            oracles_visible: round.oracles_visible,
            jobs: round.jobs,
            order_seed: round.order_seed,
            tasks_sha: round.tasks_sha.clone(),
        });

        reproducibility.push(repeats_of(&round.label, &rows, cfg));
        integrity.push(integrity_of(store, round, &rows, &meta)?);
        budget.push(budget_of(&round.label, &rows, round.budget_scale_or_default()));
        if let Some(se) = session_effect(&round.label, &rows, &meta) {
            sessions.push(se);
        }
    }

    let m_weighted = ScoreMatrix::from_triples(weighted);
    let m_uniform = ScoreMatrix::from_triples(uniform);
    let m_strict = ScoreMatrix::from_triples(strict);
    let m_by_stack = group_normalised(&m_weighted, &stack_of);

    let items = psychometrics::analyze(&m_weighted);
    let rank = robustness::rank_stability(&m_weighted, cfg.iters, cfg.seed);
    let mut group_drops = BTreeMap::new();
    for (name, map) in [("stack", &stack_of), ("tier", &tier_of), ("family", &family_of)] {
        if map.is_empty() {
            continue;
        }
        let drops = robustness::leave_one_group_out(&m_weighted, map);
        if !drops.is_empty() {
            group_drops.insert(name.to_string(), drops);
        }
    }
    let mut influence = robustness::item_influence(&m_weighted);
    influence.truncate(cfg.top_n);
    let rules = robustness::rule_agreement(
        &m_weighted,
        &[
            ("uniform-weights".into(), m_uniform),
            ("strict-all-or-nothing".into(), m_strict),
            ("per-stack-normalised".into(), m_by_stack),
        ],
    );
    let complete = m_weighted.complete_items();
    let variance = (m_weighted.n_subjects() >= 2 && complete.len() >= 2)
        .then(|| stats::variance_components(&m_weighted.dense(&complete)))
        .flatten();

    // Every ordered pair of rounds, guarded and powered.
    let mut pairs = Vec::new();
    for (i, a) in rounds.iter().enumerate() {
        for b in rounds.iter().skip(i + 1) {
            let c = crate::compare(store, a.id, b.id)?;
            pairs.push(PairPower {
                a: a.label.clone(),
                b: b.label.clone(),
                paired: c.paired_tasks,
                verified: c.paired_verified,
                unverified: c.paired_unverified,
                mismatched: c.dropped_content_mismatch,
                diff: c.capability_diff,
                ci: c.capability_diff_ci,
                sd_diff: c.sd_diff,
                mde: c.mde,
                power: c.power,
                mcnemar_p: c.mcnemar_p,
                wilcoxon_p: c.wilcoxon_p,
                underpowered: c.underpowered(),
            });
        }
    }

    let mut dead_items: Vec<String> = items
        .items
        .iter()
        .filter(|i| i.dead)
        .map(|i| i.item.clone())
        .collect();
    dead_items.truncate(cfg.top_n * 4);
    let negative_items: Vec<ItemStat> = items
        .items
        .iter()
        .filter(|i| i.negative_discrimination)
        .take(cfg.top_n)
        .cloned()
        .collect();

    Ok(RobustnessReport {
        rounds: summaries,
        dead_items,
        negative_items,
        items,
        rank,
        group_drops,
        influence,
        rules,
        variance,
        reproducibility,
        pairs,
        integrity,
        budget,
        sessions,
        oracle_audit: oracle_audit(store, cfg)?,
        drift: drift(store)?,
        contamination: contamination(store, cfg)?,
    })
}

/// Collapse items into group means, so each group counts once regardless of
/// how many tasks it happens to contain.
fn group_normalised(m: &ScoreMatrix, group_of: &BTreeMap<String, String>) -> ScoreMatrix {
    let mut groups: Vec<String> = group_of.values().cloned().collect();
    groups.sort();
    groups.dedup();
    let mut triples = Vec::new();
    for (si, subject) in m.subjects.iter().enumerate() {
        for g in &groups {
            let vals: Vec<f64> = m
                .items
                .iter()
                .enumerate()
                .filter(|(_, item)| group_of.get(*item) == Some(g))
                .map(|(j, _)| m.scores[si][j])
                .filter(|v| v.is_finite())
                .collect();
            if !vals.is_empty() {
                triples.push((subject.clone(), g.clone(), stats::mean(&vals)));
            }
        }
    }
    ScoreMatrix::from_triples(triples)
}

fn repeats_of(label: &str, rows: &[harpia_store::TrialRow], cfg: &MetaConfig) -> Reproducibility {
    let mut by_task: BTreeMap<&str, Vec<&harpia_store::TrialRow>> = BTreeMap::new();
    for r in rows {
        by_task.entry(r.task_id.as_str()).or_default().push(r);
    }
    let repeats: Vec<(&str, Vec<&harpia_store::TrialRow>)> =
        by_task.into_iter().filter(|(_, v)| v.len() > 1).collect();

    let mut flaky = Vec::new();
    let mut groups = Vec::new();
    let mut within_sds = Vec::new();
    let mut pass1 = Vec::new();
    let mut passk = Vec::new();
    let mut k_max = 0u32;
    for (task, attempts) in &repeats {
        let scores: Vec<f64> = attempts.iter().map(|a| a.capability).collect();
        let solved: Vec<bool> = scores.iter().map(|s| *s >= 1.0).collect();
        if !(solved.iter().all(|&s| s) || solved.iter().all(|&s| !s)) {
            flaky.push(task.to_string());
        }
        within_sds.push(stats::sd(&scores));
        groups.push(scores);
        let n = attempts.len() as u32;
        let c = solved.iter().filter(|&&s| s).count() as u32;
        k_max = k_max.max(n);
        pass1.push(stats::pass_at_k(n, c, 1));
        passk.push(stats::pass_at_k(n, c, n));
    }
    let repeat_tasks = repeats.len();
    Reproducibility {
        round: label.to_string(),
        repeat_tasks,
        flake_rate: if repeat_tasks == 0 {
            0.0
        } else {
            flaky.len() as f64 / repeat_tasks as f64
        },
        flaky_tasks: flaky.into_iter().take(cfg.top_n).collect(),
        icc: stats::icc_1_1(&groups),
        mean_within_sd: stats::mean(&within_sds),
        pass_at_1: stats::mean(&pass1),
        pass_at_k: stats::mean(&passk),
        k: k_max,
    }
}

fn integrity_of(
    store: &Store,
    round: &RoundRow,
    rows: &[harpia_store::TrialRow],
    meta: &[harpia_store::meta::TrialMeta],
) -> Result<Integrity> {
    let price = store.price(&round.model)?;
    let by_id: BTreeMap<i64, &harpia_store::meta::TrialMeta> =
        meta.iter().map(|m| (m.trial_id, m)).collect();

    let mut source_counts: BTreeMap<String, usize> = BTreeMap::new();
    let mut disagreements = Vec::new();
    let mut cost_errors = Vec::new();
    let mut cross_checked = 0usize;
    let (mut zero_tokens, mut zero_requests, mut null_cost, mut malformed) = (0, 0, 0, 0);
    let mut infra = 0usize;

    for r in rows {
        if r.telemetry.input_tokens + r.telemetry.output_tokens + r.telemetry.cache_read_tokens == 0
        {
            zero_tokens += 1;
        }
        if r.telemetry.requests == 0 {
            zero_requests += 1;
        }
        if r.telemetry.cost_usd.is_none() {
            null_cost += 1;
        }
        if r.outcome == Outcome::Malformed {
            malformed += 1;
        }
        if r.fault == Fault::Infra {
            infra += 1;
        }
        if let Some(m) = by_id.get(&r.id) {
            *source_counts
                .entry(m.telemetry_source.as_str().to_string())
                .or_default() += 1;
            if m.telemetry_source == TelemetrySource::Both {
                cross_checked += 1;
                if let Some(d) = m.proxy.disagreement(&r.telemetry) {
                    disagreements.push(d);
                }
            }
        }
        if let (Some(reported), Some(p)) = (r.telemetry.cost_usd, price) {
            let table = p.cost(&r.telemetry);
            if reported > 0.0 && table > 0.0 {
                cost_errors.push((reported - table).abs() / reported);
            }
        }
    }

    let firsts: Vec<&harpia_store::TrialRow> = rows.iter().filter(|r| r.attempt == 1).collect();
    let capability_excl_infra = (infra > 0).then(|| {
        let kept: Vec<f64> = firsts
            .iter()
            .filter(|r| r.fault != Fault::Infra)
            .map(|r| r.capability)
            .collect();
        stats::mean(&kept)
    });

    Ok(Integrity {
        round: round.label.clone(),
        trials: rows.len(),
        zero_tokens,
        zero_requests,
        null_cost,
        malformed,
        source_counts,
        cross_checked,
        disagreement_mean: (!disagreements.is_empty()).then(|| stats::mean(&disagreements)),
        disagreement_max: disagreements.iter().copied().reduce(f64::max),
        cost_reconciled: cost_errors.len(),
        cost_mape: (!cost_errors.is_empty()).then(|| stats::mean(&cost_errors)),
        infra_trials: infra,
        infra_rate: if rows.is_empty() { 0.0 } else { infra as f64 / rows.len() as f64 },
        infra_ci: stats::wilson_ci(infra as u64, rows.len() as u64, 0.05),
        capability_excl_infra,
    })
}

fn budget_of(label: &str, rows: &[harpia_store::TrialRow], scale: f64) -> BudgetExposure {
    let timeouts = rows.iter().filter(|r| r.outcome == Outcome::Timeout).count();
    let ceilings = rows.iter().filter(|r| r.outcome == Outcome::CostCeiling).count();
    let bound: Vec<f64> = rows
        .iter()
        .filter(|r| matches!(r.outcome, Outcome::Timeout | Outcome::CostCeiling))
        .map(|r| r.capability)
        .collect();
    BudgetExposure {
        round: label.to_string(),
        trials: rows.len(),
        timeouts,
        cost_ceilings: ceilings,
        budget_bound_share: if rows.is_empty() {
            0.0
        } else {
            (timeouts + ceilings) as f64 / rows.len() as f64
        },
        capability_when_bound: stats::mean(&bound),
        budget_scale: scale,
    }
}

fn session_effect(
    label: &str,
    rows: &[harpia_store::TrialRow],
    meta: &[harpia_store::meta::TrialMeta],
) -> Option<SessionEffect> {
    let by_id: BTreeMap<i64, &harpia_store::meta::TrialMeta> =
        meta.iter().map(|m| (m.trial_id, m)).collect();
    let mut buckets: BTreeMap<String, Vec<f64>> = BTreeMap::new();
    // Every trial, not only attempt 1: the question is whether work done in
    // one sitting scored differently from work done in another, and repeats
    // are part of that work.
    for r in rows.iter() {
        let session = by_id
            .get(&r.id)
            .and_then(|m| m.session_id.clone())
            .unwrap_or_else(|| "unrecorded".into());
        buckets.entry(session).or_default().push(r.capability);
    }
    if buckets.len() < 2 {
        return None;
    }
    let sessions: Vec<(String, usize, f64)> = buckets
        .iter()
        .map(|(k, v)| (k.clone(), v.len(), stats::mean(v)))
        .collect();
    let means: Vec<f64> = sessions.iter().map(|(_, _, m)| *m).collect();
    let max_gap = means.iter().copied().fold(f64::MIN, f64::max)
        - means.iter().copied().fold(f64::MAX, f64::min);
    Some(SessionEffect { round: label.to_string(), sessions, max_gap })
}

fn oracle_audit(store: &Store, cfg: &MetaConfig) -> Result<Option<OracleAuditSummary>> {
    let rows = store.oracle_audits(true)?;
    if rows.is_empty() {
        return Ok(None);
    }
    let tasks: BTreeSet<&str> = rows.iter().map(|r| r.task_id.as_str()).collect();
    let mutation: Vec<_> = rows.iter().filter(|r| r.kind == "mutation").collect();
    let metamorphic: Vec<_> = rows.iter().filter(|r| r.kind == "metamorphic").collect();
    let mutated: BTreeSet<&str> = mutation.iter().map(|r| r.task_id.as_str()).collect();
    let tasks_without_mutants: Vec<String> = tasks
        .iter()
        .filter(|t| !mutated.contains(*t))
        .map(|t| t.to_string())
        .collect();
    let caught = mutation.iter().filter(|r| r.passed).count();
    let held = metamorphic.iter().filter(|r| r.passed).count();
    Ok(Some(OracleAuditSummary {
        tasks_audited: tasks.len(),
        mutation_total: mutation.len(),
        mutation_caught: caught,
        mutation_score: if mutation.is_empty() {
            0.0
        } else {
            caught as f64 / mutation.len() as f64
        },
        mutation_ci: stats::wilson_ci(caught as u64, mutation.len() as u64, cfg.alpha),
        survivors: mutation
            .iter()
            .filter(|r| !r.passed)
            .take(cfg.top_n)
            .map(|r| (r.task_id.clone(), r.operator.clone()))
            .collect(),
        metamorphic_total: metamorphic.len(),
        metamorphic_held: held,
        invariance: if metamorphic.is_empty() {
            0.0
        } else {
            held as f64 / metamorphic.len() as f64
        },
        invariance_ci: stats::wilson_ci(held as u64, metamorphic.len() as u64, cfg.alpha),
        false_fails: metamorphic
            .iter()
            .filter(|r| !r.passed)
            .take(cfg.top_n)
            .map(|r| (r.task_id.clone(), r.operator.clone()))
            .collect(),
        tasks_without_mutants,
    }))
}

fn drift(store: &Store) -> Result<Option<DriftSummary>> {
    let epochs = store.latest_two_check_epochs()?;
    if epochs.len() < 2 {
        return Ok(None);
    }
    let (latest, previous) = (epochs[0], epochs[1]);
    let rows = store.corpus_checks()?;
    let at = |epoch: i64| -> BTreeMap<String, &harpia_store::meta::CorpusCheckRow> {
        rows.iter()
            .filter(|r| r.at_epoch == epoch)
            .map(|r| (r.task_id.clone(), r))
            .collect()
    };
    let before = at(previous);
    let after = at(latest);

    let mut newly_failing = Vec::new();
    let mut newly_passing = Vec::new();
    let mut content_changed = Vec::new();
    let mut marginal = Vec::new();
    for (task, now) in &after {
        if let Some(then) = before.get(task) {
            if then.ok && !now.ok {
                newly_failing.push(task.clone());
            }
            if !then.ok && now.ok {
                newly_passing.push(task.clone());
            }
            if then.content_sha != now.content_sha {
                content_changed.push(task.clone());
            }
        }
        // A starter within a third of the floor is one flaky assertion from
        // being non-discriminative.
        if now.ok && now.starter_capability > harpia_runner_floor() / 3.0 {
            marginal.push((task.clone(), now.starter_capability));
        }
    }
    marginal.sort_by(|a, b| b.1.total_cmp(&a.1));
    marginal.truncate(10);

    let tool_before = after
        .values()
        .next()
        .and_then(|_| before.values().next())
        .and_then(|r| r.toolchain.clone())
        .unwrap_or_default();
    let tool_after = after
        .values()
        .next()
        .and_then(|r| r.toolchain.clone())
        .unwrap_or_default();
    let toolchain_changes = toolchain_diff(&tool_before, &tool_after);

    Ok(Some(DriftSummary {
        previous_epoch: previous,
        latest_epoch: latest,
        newly_failing,
        newly_passing,
        content_changed,
        toolchain_changes,
        marginal_tasks: marginal,
    }))
}

/// The starter-capability floor `harpia validate` enforces. Duplicated as a
/// constant rather than depending on the runner: the report crate must stay
/// readable from a database alone, with no run-side code in the graph.
fn harpia_runner_floor() -> f64 {
    0.05
}

fn toolchain_diff(before: &str, after: &str) -> Vec<(String, Option<String>, Option<String>)> {
    let b: BTreeMap<String, String> = serde_json::from_str(before).unwrap_or_default();
    let a: BTreeMap<String, String> = serde_json::from_str(after).unwrap_or_default();
    let mut keys: Vec<&String> = b.keys().chain(a.keys()).collect();
    keys.sort();
    keys.dedup();
    keys.into_iter()
        .filter(|k| b.get(*k) != a.get(*k))
        .map(|k| (k.clone(), b.get(k).cloned(), a.get(k).cloned()))
        .collect()
}

fn contamination(store: &Store, cfg: &MetaConfig) -> Result<Option<ContaminationSummary>> {
    let rows = store.contamination_rows()?;
    if rows.is_empty() {
        return Ok(None);
    }
    let sims: Vec<f64> = rows.iter().filter_map(|r| r.max_similarity).collect();
    let mut worst: Vec<(String, f64, String)> = rows
        .iter()
        .filter_map(|r| {
            r.max_similarity.map(|s| {
                (
                    r.task_id.clone(),
                    s,
                    r.nearest_source.clone().unwrap_or_else(|| "-".into()),
                )
            })
        })
        .collect();
    worst.sort_by(|a, b| b.1.total_cmp(&a.1));
    worst.truncate(cfg.top_n);
    Ok(Some(ContaminationSummary {
        tasks: rows.len(),
        with_canary: rows.iter().filter(|r| r.canary.is_some()).count(),
        unique_canaries: rows.iter().filter(|r| r.canary_unique == Some(true)).count(),
        similarity_p50: stats::quantile(&sims, 0.5),
        similarity_p95: stats::quantile(&sims, 0.95),
        similarity_max: sims.iter().copied().fold(0.0, f64::max),
        worst,
    }))
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

pub fn render_text(r: &RobustnessReport) -> String {
    let mut o = String::new();
    let pct = |x: f64| format!("{:.0}%", x * 100.0);
    let opt = |x: Option<f64>| x.map(|v| format!("{v:.3}")).unwrap_or_else(|| "n/a".into());

    o.push_str("== rounds =====================================================\n");
    for s in &r.rounds {
        o.push_str(&format!(
            "  {:<26} {:<12} {:<20} cap {:.3}  n {:<4} budget x{:.1}{}{}\n",
            s.label,
            s.harness,
            s.model,
            s.capability,
            s.tasks,
            s.budget_scale,
            if s.prompt_variant > 0 { format!("  wording {}", s.prompt_variant) } else { String::new() },
            if s.oracles_visible { "  ORACLES VISIBLE" } else { "" },
        ));
    }

    o.push_str("\n== items ======================================================\n");
    let i = &r.items;
    o.push_str(&format!(
        "  {} items over {} rounds: {} live, {} dead ({} ceiling, {} floor), {} negative\n",
        i.n_items, i.n_subjects, i.live_items, i.dead_items, i.ceiling_items, i.floor_items,
        i.negative_items
    ));
    o.push_str(&format!(
        "  effective n = {} (the n a confidence interval is entitled to)\n",
        i.effective_n()
    ));
    if let Some(rel) = &i.reliability {
        o.push_str(&format!(
            "  reliability: alpha {}  split-half {}  sd(total) {:.3}  SEM {}\n",
            opt(rel.alpha),
            opt(rel.split_half),
            rel.sd_total,
            opt(rel.sem)
        ));
    } else {
        o.push_str("  reliability: not computable (needs >= 2 rounds over shared items)\n");
    }
    if !r.negative_items.is_empty() {
        o.push_str("  items that rank harnesses backwards:\n");
        for it in &r.negative_items {
            o.push_str(&format!(
                "    {:<30} r = {}\n",
                it.item,
                opt(it.discrimination)
            ));
        }
    }

    o.push_str("\n== ranking robustness =========================================\n");
    match &r.rank {
        Some(rs) => {
            o.push_str(&format!(
                "  bootstrap over {} items x {} resamples: order preserved {}\n",
                rs.items_used,
                rs.iters,
                pct(rs.order_preserved)
            ));
            o.push_str(&format!(
                "  Kendall tau vs full corpus: median {:.3}, 5th pct {:.3}\n",
                rs.tau_median, rs.tau_p05
            ));
            for (subject, share) in &rs.top1 {
                o.push_str(&format!("    led in {} of resamples: {subject}\n", pct(*share)));
            }
            if let Some(p) = rs.most_fragile() {
                o.push_str(&format!(
                    "  most fragile pair: {} over {} (gap {:.3}) flips {} of the time\n",
                    p.ahead,
                    p.behind,
                    p.gap,
                    pct(p.flip_rate)
                ));
            }
        }
        None => o.push_str("  not computable (needs >= 2 rounds over >= 2 shared items)\n"),
    }

    for (name, drops) in &r.group_drops {
        o.push_str(&format!("\n  leave-one-{name}-out:\n"));
        for d in drops {
            let top = d.leaderboard.first().map(|(s, _)| s.as_str()).unwrap_or("-");
            o.push_str(&format!(
                "    without {:<12} ({:>3} items left) leader {:<26}{}\n",
                d.group,
                d.items_left,
                top,
                if d.top_changed { "  LEADER CHANGES" } else { "" }
            ));
        }
    }

    if !r.influence.is_empty() {
        o.push_str("\n  single tasks with the most influence on the top-two gap:\n");
        for inf in &r.influence {
            o.push_str(&format!(
                "    {:<32} gap {:+.4}{}\n",
                inf.item,
                inf.top_gap_delta,
                if inf.flips_top { "   FLIPS THE WINNER" } else { "" }
            ));
        }
    }

    o.push_str("\n== scoring-rule sensitivity ===================================\n");
    for rule in &r.rules {
        o.push_str(&format!(
            "  {:<22} leader {:<26} tau {}  {}\n",
            rule.rule,
            rule.top.clone().unwrap_or_else(|| "-".into()),
            opt(rule.tau_vs_reference),
            if rule.order_matches_reference { "order holds" } else { "ORDER CHANGES" }
        ));
    }

    if let Some(v) = &r.variance {
        o.push_str("\n== variance decomposition =====================================\n");
        o.push_str(&format!(
            "  round {} | task {} | residual {}\n",
            pct(v.row_share()),
            pct(v.col_share()),
            pct(v.residual_share())
        ));
        if v.row_share() < v.residual_share() {
            o.push_str("  residual exceeds the round effect: the ranking is inside the noise\n");
        }
    }

    o.push_str("\n== reproducibility ============================================\n");
    for rep in &r.reproducibility {
        if rep.repeat_tasks == 0 {
            o.push_str(&format!("  {:<26} no repeats recorded\n", rep.round));
            continue;
        }
        o.push_str(&format!(
            "  {:<26} {} repeat tasks: flake {}  ICC {}  within-sd {:.3}  pass@1 {:.3} pass@{} {:.3}\n",
            rep.round,
            rep.repeat_tasks,
            pct(rep.flake_rate),
            opt(rep.icc),
            rep.mean_within_sd,
            rep.pass_at_1,
            rep.k,
            rep.pass_at_k
        ));
        if !rep.flaky_tasks.is_empty() {
            o.push_str(&format!("      flapping: {}\n", rep.flaky_tasks.join(", ")));
        }
    }

    o.push_str("\n== paired power ===============================================\n");
    for p in &r.pairs {
        o.push_str(&format!(
            "  {} vs {}: n {} ({} verified, {} unverified, {} dropped)\n",
            p.a, p.b, p.paired, p.verified, p.unverified, p.mismatched
        ));
        o.push_str(&format!(
            "      diff {:+.3}{}  sd {:.3}  MDE@80% {}  power {}  McNemar p {:.4}{}\n",
            p.diff,
            p.ci.map(|(lo, hi)| format!(" [{lo:+.3}, {hi:+.3}]")).unwrap_or_default(),
            p.sd_diff,
            opt(p.mde),
            p.power.map(pct_or).unwrap_or_else(|| "n/a".into()),
            p.mcnemar_p,
            if p.underpowered { "   UNDERPOWERED" } else { "" }
        ));
    }

    o.push_str("\n== instrumentation integrity ==================================\n");
    for it in &r.integrity {
        o.push_str(&format!(
            "  {:<26} {} trials: zero-token {}  zero-request {}  null-cost {}  malformed {}\n",
            it.round, it.trials, it.zero_tokens, it.zero_requests, it.null_cost, it.malformed
        ));
        let sources: Vec<String> = it
            .source_counts
            .iter()
            .map(|(k, v)| format!("{k} {v}"))
            .collect();
        o.push_str(&format!(
            "      sources: {}   cross-checked {}   disagreement mean {} max {}\n",
            if sources.is_empty() { "unrecorded".into() } else { sources.join(", ") },
            it.cross_checked,
            opt(it.disagreement_mean),
            opt(it.disagreement_max)
        ));
        o.push_str(&format!(
            "      cost reconciled on {} trials, MAPE {}   infra faults {} ({})\n",
            it.cost_reconciled,
            it.cost_mape.map(pct_or).unwrap_or_else(|| "n/a".into()),
            it.infra_trials,
            pct(it.infra_rate)
        ));
        if let Some(c) = it.capability_excl_infra {
            o.push_str(&format!("      capability excluding infra faults: {c:.3}\n"));
        }
    }

    o.push_str("\n== budget exposure ============================================\n");
    for b in &r.budget {
        o.push_str(&format!(
            "  {:<26} timeouts {:<4} ceilings {:<4} budget-bound {}  cap when bound {:.3}  (x{:.1})\n",
            b.round,
            b.timeouts,
            b.cost_ceilings,
            pct(b.budget_bound_share),
            b.capability_when_bound,
            b.budget_scale
        ));
    }

    if !r.sessions.is_empty() {
        o.push_str("\n== batch effects ==============================================\n");
        for s in &r.sessions {
            o.push_str(&format!(
                "  {:<26} {} sessions, largest capability gap {:.3}\n",
                s.round,
                s.sessions.len(),
                s.max_gap
            ));
            for (id, n, mean) in &s.sessions {
                o.push_str(&format!("      {id:<24} n {n:<4} cap {mean:.3}\n"));
            }
        }
    }

    o.push_str("\n== oracle validity ============================================\n");
    match &r.oracle_audit {
        Some(a) => {
            o.push_str(&format!(
                "  {} tasks audited\n  mutation score {:.3}{} ({}/{} mutants caught)\n",
                a.tasks_audited,
                a.mutation_score,
                a.mutation_ci
                    .map(|(lo, hi)| format!(" [{lo:.3}, {hi:.3}]"))
                    .unwrap_or_default(),
                a.mutation_caught,
                a.mutation_total
            ));
            o.push_str(&format!(
                "  invariance     {:.3}{} ({}/{} rewrites still pass)\n",
                a.invariance,
                a.invariance_ci
                    .map(|(lo, hi)| format!(" [{lo:.3}, {hi:.3}]"))
                    .unwrap_or_default(),
                a.metamorphic_held,
                a.metamorphic_total
            ));
            for (task, op) in &a.survivors {
                o.push_str(&format!("    survived: {task} ({op}) — oracle accepts broken code\n"));
            }
            for (task, op) in &a.false_fails {
                o.push_str(&format!("    false fail: {task} ({op}) — oracle rejects correct code\n"));
            }
            if !a.tasks_without_mutants.is_empty() {
                o.push_str(&format!(
                    "  {} task(s) produced no mutant at all — unaudited, not clean: {}\n",
                    a.tasks_without_mutants.len(),
                    a.tasks_without_mutants.join(", ")
                ));
            }
        }
        None => o.push_str("  never audited — run `harpia audit`\n"),
    }

    o.push_str("\n== corpus drift ===============================================\n");
    match &r.drift {
        Some(d) => {
            o.push_str(&format!(
                "  between validations {} and {}: {} newly failing, {} newly passing, {} edited\n",
                d.previous_epoch,
                d.latest_epoch,
                d.newly_failing.len(),
                d.newly_passing.len(),
                d.content_changed.len()
            ));
            for t in d.newly_failing.iter().take(10) {
                o.push_str(&format!("    now failing: {t}\n"));
            }
            for (tool, before, after) in &d.toolchain_changes {
                o.push_str(&format!(
                    "    toolchain {tool}: {} -> {}\n",
                    before.clone().unwrap_or_else(|| "absent".into()),
                    after.clone().unwrap_or_else(|| "absent".into())
                ));
            }
            for (task, starter) in d.marginal_tasks.iter().take(5) {
                o.push_str(&format!("    marginal: {task} starter {starter:.3}\n"));
            }
        }
        None => o.push_str("  fewer than two validation sweeps recorded — run `harpia validate --record`\n"),
    }

    o.push_str("\n== contamination ==============================================\n");
    match &r.contamination {
        Some(c) => {
            o.push_str(&format!(
                "  {} tasks: {} carry a canary, {} of those unique\n",
                c.tasks, c.with_canary, c.unique_canaries
            ));
            o.push_str(&format!(
                "  containment p50 {:.3}  p95 {:.3}  max {:.3}\n",
                c.similarity_p50, c.similarity_p95, c.similarity_max
            ));
            for (task, sim, src) in &c.worst {
                o.push_str(&format!("    {task:<30} {sim:.3} vs {src}\n"));
            }
        }
        None => o.push_str("  never scanned — run `harpia contamination`\n"),
    }
    o
}

fn pct_or(x: f64) -> String {
    format!("{:.1}%", x * 100.0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use harpia_core::metrics::{Fault, Outcome, ProxyUsage, Telemetry, TelemetrySource};
    use harpia_store::{TrialProvenance, TrialRecord};

    struct Trial<'a> {
        task: &'a str,
        attempt: u32,
        solved: bool,
        outcome: Outcome,
        fault: Fault,
        sha: Option<&'a str>,
        session: &'a str,
    }

    fn record(store: &mut Store, round: i64, t: Trial) {
        let tel = Telemetry {
            input_tokens: 100,
            output_tokens: 50,
            requests: 2,
            wall_ms: 1000,
            cost_usd: Some(0.01),
            ..Default::default()
        };
        store
            .record_trial(&TrialRecord {
                round_id: round,
                task_id: t.task,
                attempt: t.attempt,
                outcome: t.outcome,
                telemetry: &tel,
                diff_stat: None,
                oracles: &[
                    ("hidden-tests".into(), t.solved, 3.0, None),
                    ("build".into(), true, 1.0, None),
                    ("security".into(), true, 1.0, None),
                ],
                tools: &[],
                model_calls: &[],
                started_epoch: None,
                finished_epoch: None,
                rung: None,
                steps: None,
                stop_reason: None,
                provenance: TrialProvenance {
                    fault: t.fault,
                    telemetry_source: TelemetrySource::Both,
                    proxy: Some(ProxyUsage {
                        input_tokens: 100,
                        output_tokens: 50,
                        requests: 2,
                        ..Default::default()
                    }),
                    task_content_sha: t.sha,
                    session_id: Some(t.session),
                    prompt_variant: 0,
                },
            })
            .unwrap();
    }

    fn seeded() -> (Store, Vec<i64>) {
        let mut s = Store::open_in_memory().unwrap();
        s.upsert_harness("ha", "0", None, "").unwrap();
        s.upsert_harness("hb", "0", None, "").unwrap();
        for i in 0..10 {
            let stack = if i < 5 { "rust" } else { "node" };
            s.upsert_task_full(
                &format!("t{i:02}"),
                stack,
                "mid",
                "task",
                "",
                Some("sha-v1"),
                Some("build"),
            )
            .unwrap();
        }
        let ra = s.begin_round("round-a", "ha", "m", None, "corpus", "now").unwrap();
        let rb = s.begin_round("round-b", "hb", "m", None, "corpus", "now").unwrap();
        // A solves the rust half, B solves the node half plus one extra.
        for i in 0..10 {
            record(
                &mut s,
                ra,
                Trial {
                    task: &format!("t{i:02}"),
                    attempt: 1,
                    solved: i < 5,
                    outcome: Outcome::Finished,
                    fault: Fault::None,
                    sha: Some("sha-v1"),
                    session: "s1",
                },
            );
            record(
                &mut s,
                rb,
                Trial {
                    task: &format!("t{i:02}"),
                    attempt: 1,
                    solved: i >= 4,
                    outcome: Outcome::Finished,
                    fault: Fault::None,
                    sha: Some("sha-v1"),
                    session: "s1",
                },
            );
        }
        (s, vec![ra, rb])
    }

    #[test]
    fn item_analysis_and_ranking_come_out_of_the_database() {
        let (s, ids) = seeded();
        let r = robustness(&s, &ids, &MetaConfig::default()).unwrap();
        assert_eq!(r.rounds.len(), 2);
        assert_eq!(r.items.n_items, 10);
        // t04 is solved by both; nothing is solved by neither.
        assert_eq!(r.items.ceiling_items, 1);
        assert_eq!(r.items.live_items, 9);
        let rank = r.rank.expect("two rounds over ten shared items");
        assert_eq!(rank.items_used, 10);
        assert!(rank.top1.values().sum::<f64>() > 0.99);
        // Leave-one-stack-out must exist for both stacks.
        let stacks = &r.group_drops["stack"];
        assert_eq!(stacks.len(), 2);
        assert!(stacks.iter().any(|d| d.top_changed), "the stacks split the verdict");
    }

    #[test]
    fn a_content_edit_between_rounds_drops_the_pairing() {
        let (s, ids) = seeded();
        // Round B re-ran t00 against an edited task.
        s.conn
            .execute(
                "UPDATE trial SET task_content_sha = 'sha-v2' WHERE round_id = ?1 AND task_id = 't00'",
                [ids[1]],
            )
            .unwrap();
        let r = robustness(&s, &ids, &MetaConfig::default()).unwrap();
        let pair = &r.pairs[0];
        assert_eq!(pair.mismatched, 1);
        assert_eq!(pair.paired, 9);
        assert_eq!(pair.verified, 9);
    }

    #[test]
    fn mde_is_reported_beside_every_pair() {
        let (s, ids) = seeded();
        let r = robustness(&s, &ids, &MetaConfig::default()).unwrap();
        let pair = &r.pairs[0];
        assert!(pair.mde.is_some());
        assert!(pair.sd_diff > 0.0);
        assert!(pair.power.is_some());
    }

    #[test]
    fn repeats_flake_and_infra_faults_are_surfaced() {
        let (mut s, ids) = seeded();
        // t00 gets two more attempts in round A, disagreeing with attempt 1.
        record(
            &mut s,
            ids[0],
            Trial {
                task: "t00",
                attempt: 2,
                solved: false,
                outcome: Outcome::Crashed,
                fault: Fault::Infra,
                sha: Some("sha-v1"),
                session: "s2",
            },
        );
        record(
            &mut s,
            ids[0],
            Trial {
                task: "t00",
                attempt: 3,
                solved: true,
                outcome: Outcome::Finished,
                fault: Fault::None,
                sha: Some("sha-v1"),
                session: "s2",
            },
        );
        let r = robustness(&s, &ids, &MetaConfig::default()).unwrap();
        let rep = r.reproducibility.iter().find(|x| x.round == "round-a").unwrap();
        assert_eq!(rep.repeat_tasks, 1);
        assert!((rep.flake_rate - 1.0).abs() < 1e-12);
        assert_eq!(rep.flaky_tasks, vec!["t00".to_string()]);

        let integ = r.integrity.iter().find(|x| x.round == "round-a").unwrap();
        assert_eq!(integ.infra_trials, 1);
        assert_eq!(integ.cross_checked, 12);
        assert_eq!(integ.disagreement_max, Some(0.0), "identical counts must agree");

        let sess = r.sessions.iter().find(|x| x.round == "round-a").unwrap();
        assert_eq!(sess.sessions.len(), 2);
    }

    #[test]
    fn scoring_rules_are_recomputed_not_reused() {
        let (s, ids) = seeded();
        let r = robustness(&s, &ids, &MetaConfig::default()).unwrap();
        let names: Vec<&str> = r.rules.iter().map(|x| x.rule.as_str()).collect();
        assert!(names.contains(&"uniform-weights"));
        assert!(names.contains(&"strict-all-or-nothing"));
        assert!(names.contains(&"per-stack-normalised"));
        // Weighted scoring gives partial credit for the always-passing build
        // oracle; strict scoring does not, so the numbers must differ.
        let strict = r.rules.iter().find(|x| x.rule == "strict-all-or-nothing").unwrap();
        let weighted_top = r
            .rounds
            .iter()
            .map(|s| s.capability)
            .fold(f64::MIN, f64::max);
        let strict_top = strict.leaderboard.first().map(|(_, v)| *v).unwrap();
        assert!(strict_top < weighted_top, "strict {strict_top} vs weighted {weighted_top}");
    }

    #[test]
    fn the_text_report_names_every_section() {
        let (s, ids) = seeded();
        let text = render_text(&robustness(&s, &ids, &MetaConfig::default()).unwrap());
        for section in [
            "== items", "== ranking robustness", "== scoring-rule sensitivity",
            "== reproducibility", "== paired power", "== instrumentation integrity",
            "== budget exposure", "== oracle validity", "== corpus drift", "== contamination",
        ] {
            assert!(text.contains(section), "missing {section}");
        }
        assert!(text.contains("never audited"), "an unrun audit must say so, not score 1.0");
    }
}
