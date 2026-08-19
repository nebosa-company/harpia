//! Does the leaderboard survive being poked?
//!
//! A capability mean is one number computed one way over one corpus. This
//! module re-computes it many other defensible ways — resampling the tasks,
//! dropping a whole stack, changing the scoring rule, removing one item — and
//! reports how often the ordering it produced survives. An ordering that only
//! holds under the exact choices its author made is not a finding.

use crate::matrix::ScoreMatrix;
use crate::rng::Rng;
use crate::stats;
use serde::Serialize;
use std::collections::BTreeMap;

/// Mean score per subject over the given item columns, ignoring missing cells.
pub fn subject_means(m: &ScoreMatrix, items: &[usize]) -> Vec<f64> {
    m.scores
        .iter()
        .map(|row| {
            let vals: Vec<f64> = items.iter().map(|&j| row[j]).filter(|v| v.is_finite()).collect();
            if vals.is_empty() { f64::NAN } else { stats::mean(&vals) }
        })
        .collect()
}

/// Subjects ordered best-first.
pub fn leaderboard(m: &ScoreMatrix, items: &[usize]) -> Vec<(String, f64)> {
    let means = subject_means(m, items);
    let mut out: Vec<(String, f64)> = m
        .subjects
        .iter()
        .cloned()
        .zip(means)
        .filter(|(_, v)| v.is_finite())
        .collect();
    out.sort_by(|a, b| b.1.total_cmp(&a.1));
    out
}

#[derive(Debug, Clone, Serialize)]
pub struct PairFlip {
    pub ahead: String,
    pub behind: String,
    /// Gap on the full corpus (always positive).
    pub gap: f64,
    /// Share of resamples where the ordering reversed or tied.
    pub flip_rate: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct RankStability {
    pub iters: u32,
    /// Items resampled — the complete-case columns.
    pub items_used: usize,
    /// Share of resamples reproducing the full-corpus order exactly.
    pub order_preserved: f64,
    /// Share of resamples in which each subject came first.
    pub top1: BTreeMap<String, f64>,
    pub mean_tau: f64,
    /// 5th percentile of Kendall tau against the full-corpus ordering.
    pub tau_p05: f64,
    pub tau_median: f64,
    /// Every ordered pair, worst (most fragile) first.
    pub pairs: Vec<PairFlip>,
}

impl RankStability {
    /// The pair most at risk of being an artefact of task selection.
    pub fn most_fragile(&self) -> Option<&PairFlip> {
        self.pairs.first()
    }
}

/// Bootstrap the corpus: resample tasks with replacement, rebuild the
/// leaderboard, and count how often it matches. This is the direct answer to
/// "would another 260 tasks of the same kind have ranked these the same way".
pub fn rank_stability(m: &ScoreMatrix, iters: u32, seed: u64) -> Option<RankStability> {
    let items = m.complete_items();
    if m.n_subjects() < 2 || items.len() < 2 || iters == 0 {
        return None;
    }
    let full = subject_means(m, &items);
    let full_order: Vec<usize> = order_desc(&full);

    let mut rng = Rng::new(seed);
    let mut taus = Vec::with_capacity(iters as usize);
    let mut preserved = 0u32;
    let mut top1: BTreeMap<String, u32> = BTreeMap::new();
    let n_subj = m.n_subjects();
    let mut flips = vec![vec![0u32; n_subj]; n_subj];

    for _ in 0..iters {
        let draw: Vec<usize> = (0..items.len()).map(|_| items[rng.below(items.len())]).collect();
        let boot = subject_means(m, &draw);
        // Strictly: a resample that ties two subjects has not reproduced an
        // ordering that separated them. Letting the index tie-break count as
        // agreement is how a one-task lead reads as settled.
        if full_order
            .windows(2)
            .all(|w| boot[w[0]] > boot[w[1]])
        {
            preserved += 1;
        }
        if let Some(&winner) = order_desc(&boot).first() {
            *top1.entry(m.subjects[winner].clone()).or_default() += 1;
        }
        if let Some(t) = stats::kendall_tau_b(&full, &boot) {
            taus.push(t);
        }
        for i in 0..n_subj {
            for j in 0..n_subj {
                if i == j || !full[i].is_finite() || !full[j].is_finite() {
                    continue;
                }
                // A tie counts as a flip: the resample failed to
                // reproduce an ordering the full corpus asserted.
                let held = matches!(
                    boot[i].partial_cmp(&boot[j]),
                    Some(std::cmp::Ordering::Greater)
                );
                if full[i] > full[j] && !held {
                    flips[i][j] += 1;
                }
            }
        }
    }

    let itersf = iters as f64;
    let mut pairs = Vec::new();
    for i in 0..n_subj {
        for j in 0..n_subj {
            if i == j || !full[i].is_finite() || !full[j].is_finite() || full[i] <= full[j] {
                continue;
            }
            pairs.push(PairFlip {
                ahead: m.subjects[i].clone(),
                behind: m.subjects[j].clone(),
                gap: full[i] - full[j],
                flip_rate: flips[i][j] as f64 / itersf,
            });
        }
    }
    pairs.sort_by(|a, b| b.flip_rate.total_cmp(&a.flip_rate));

    Some(RankStability {
        iters,
        items_used: items.len(),
        order_preserved: preserved as f64 / itersf,
        top1: top1
            .into_iter()
            .map(|(k, v)| (k, v as f64 / itersf))
            .collect(),
        mean_tau: stats::mean(&taus),
        tau_p05: stats::quantile(&taus, 0.05),
        tau_median: stats::median(&taus),
        pairs,
    })
}

#[derive(Debug, Clone, Serialize)]
pub struct GroupDrop {
    pub group: String,
    pub items_dropped: usize,
    pub items_left: usize,
    pub leaderboard: Vec<(String, f64)>,
    pub tau_vs_full: Option<f64>,
    /// The winner changed when this group was removed.
    pub top_changed: bool,
}

/// Leave-one-group-out: recompute the leaderboard with each stack (or tier,
/// or task family) removed. A benchmark whose verdict depends on one stack is
/// that stack's benchmark, whatever its title says.
pub fn leave_one_group_out(m: &ScoreMatrix, group_of: &BTreeMap<String, String>) -> Vec<GroupDrop> {
    let all: Vec<usize> = (0..m.n_items()).collect();
    let full = subject_means(m, &all);
    let full_top = order_desc(&full).first().map(|&i| m.subjects[i].clone());

    let mut groups: Vec<String> = group_of.values().cloned().collect();
    groups.sort();
    groups.dedup();

    groups
        .into_iter()
        .map(|g| {
            let keep: Vec<usize> = (0..m.n_items())
                .filter(|&j| group_of.get(&m.items[j]) != Some(&g))
                .collect();
            let dropped = m.n_items() - keep.len();
            let reduced = subject_means(m, &keep);
            let top = order_desc(&reduced).first().map(|&i| m.subjects[i].clone());
            GroupDrop {
                group: g,
                items_dropped: dropped,
                items_left: keep.len(),
                leaderboard: leaderboard(m, &keep),
                tau_vs_full: stats::kendall_tau_b(&full, &reduced),
                top_changed: top != full_top,
            }
        })
        .collect()
}

#[derive(Debug, Clone, Serialize)]
pub struct ItemInfluence {
    pub item: String,
    /// Change in the top-two gap when this single item is removed.
    pub top_gap_delta: f64,
    /// Removing this one item alone changes who wins.
    pub flips_top: bool,
}

/// Jackknife over items: how much does any single task move the verdict?
/// One task that can flip the winner is a finding about the corpus, not the
/// harnesses.
pub fn item_influence(m: &ScoreMatrix) -> Vec<ItemInfluence> {
    let all: Vec<usize> = (0..m.n_items()).collect();
    let full = subject_means(m, &all);
    let full_order = order_desc(&full);
    if full_order.len() < 2 {
        return Vec::new();
    }
    let full_gap = full[full_order[0]] - full[full_order[1]];
    let full_top = full_order[0];

    let mut out: Vec<ItemInfluence> = (0..m.n_items())
        .map(|drop| {
            let keep: Vec<usize> = all.iter().copied().filter(|&j| j != drop).collect();
            let means = subject_means(m, &keep);
            let order = order_desc(&means);
            let gap = if order.len() >= 2 {
                means[order[0]] - means[order[1]]
            } else {
                0.0
            };
            ItemInfluence {
                item: m.items[drop].clone(),
                top_gap_delta: gap - full_gap,
                flips_top: order.first() != Some(&full_top),
            }
        })
        .collect();
    out.sort_by(|a, b| b.top_gap_delta.abs().total_cmp(&a.top_gap_delta.abs()));
    out
}

#[derive(Debug, Clone, Serialize)]
pub struct RuleRanking {
    pub rule: String,
    pub leaderboard: Vec<(String, f64)>,
    pub top: Option<String>,
    pub tau_vs_reference: Option<f64>,
    pub order_matches_reference: bool,
}

/// Rescore under alternative aggregation rules and compare orderings. If the
/// ranking only holds under one weighting, the weighting is the result.
pub fn rule_agreement(reference: &ScoreMatrix, variants: &[(String, ScoreMatrix)]) -> Vec<RuleRanking> {
    let ref_items: Vec<usize> = (0..reference.n_items()).collect();
    let ref_means = subject_means(reference, &ref_items);
    let ref_order: Vec<String> = order_desc(&ref_means)
        .into_iter()
        .map(|i| reference.subjects[i].clone())
        .collect();

    variants
        .iter()
        .map(|(name, m)| {
            let items: Vec<usize> = (0..m.n_items()).collect();
            let means = subject_means(m, &items);
            let order: Vec<String> = order_desc(&means)
                .into_iter()
                .map(|i| m.subjects[i].clone())
                .collect();
            // Compare only on subjects both matrices scored.
            let aligned: Option<(Vec<f64>, Vec<f64>)> = {
                let mut a = Vec::new();
                let mut b = Vec::new();
                for (si, s) in reference.subjects.iter().enumerate() {
                    if let Some(oi) = m.subject_index(s) {
                        if ref_means[si].is_finite() && means[oi].is_finite() {
                            a.push(ref_means[si]);
                            b.push(means[oi]);
                        }
                    }
                }
                (a.len() >= 2).then_some((a, b))
            };
            RuleRanking {
                rule: name.clone(),
                top: order.first().cloned(),
                order_matches_reference: order == ref_order,
                tau_vs_reference: aligned.and_then(|(a, b)| stats::kendall_tau_b(&a, &b)),
                leaderboard: leaderboard(m, &items),
            }
        })
        .collect()
}

/// Indices of finite values, best-first. Ties break on index so the ordering
/// is total and comparisons between resamples stay meaningful.
fn order_desc(values: &[f64]) -> Vec<usize> {
    let mut idx: Vec<usize> = (0..values.len()).filter(|&i| values[i].is_finite()).collect();
    idx.sort_by(|&a, &b| values[b].total_cmp(&values[a]).then(a.cmp(&b)));
    idx
}

#[cfg(test)]
mod tests {
    use super::*;

    fn matrix(rows: &[(&str, &[f64])]) -> ScoreMatrix {
        let items: Vec<String> = (0..rows[0].1.len()).map(|j| format!("t{j:02}")).collect();
        let mut triples = Vec::new();
        for (s, scores) in rows {
            for (j, v) in scores.iter().enumerate() {
                triples.push((s.to_string(), items[j].clone(), *v));
            }
        }
        ScoreMatrix::from_triples(triples)
    }

    #[test]
    fn a_wide_consistent_gap_is_stable() {
        let strong: Vec<f64> = (0..40).map(|i| if i % 10 == 0 { 0.0 } else { 1.0 }).collect();
        let weak: Vec<f64> = (0..40).map(|i| if i % 10 == 0 { 1.0 } else { 0.0 }).collect();
        let m = matrix(&[("strong", &strong), ("weak", &weak)]);
        let rs = rank_stability(&m, 2000, 1).unwrap();
        assert!(rs.order_preserved > 0.99, "preserved {}", rs.order_preserved);
        assert!(rs.top1["strong"] > 0.99);
        assert!(rs.most_fragile().unwrap().flip_rate < 0.01);
    }

    #[test]
    fn a_hairline_gap_is_not_stable() {
        // 20 items; the two rounds differ on exactly one of them.
        let mut a = vec![1.0; 20];
        let mut b = vec![1.0; 20];
        a[0] = 0.0;
        a[1] = 0.0;
        b[0] = 0.0;
        let m = matrix(&[("b", &b), ("a", &a)]);
        let rs = rank_stability(&m, 4000, 2).unwrap();
        assert!(
            rs.order_preserved < 0.75,
            "a one-task lead should not read as settled: {}",
            rs.order_preserved
        );
        assert!(rs.most_fragile().unwrap().flip_rate > 0.25);
    }

    #[test]
    fn rank_stability_is_deterministic() {
        let m = matrix(&[("x", &[1.0, 0.0, 1.0, 1.0]), ("y", &[0.0, 1.0, 0.0, 0.0])]);
        let one = rank_stability(&m, 500, 9).unwrap();
        let two = rank_stability(&m, 500, 9).unwrap();
        assert_eq!(one.order_preserved, two.order_preserved);
        assert_eq!(one.mean_tau, two.mean_tau);
    }

    #[test]
    fn leave_one_group_out_finds_a_one_stack_verdict() {
        // A wins only because of the four "rust" items; B wins everywhere else.
        let a = [1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0];
        let b = [0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4, 0.4];
        let m = matrix(&[("A", &a), ("B", &b)]);
        let groups: BTreeMap<String, String> = m
            .items
            .iter()
            .enumerate()
            .map(|(j, name)| {
                (name.clone(), if j < 4 { "rust".to_string() } else { "node".to_string() })
            })
            .collect();
        let drops = leave_one_group_out(&m, &groups);
        let rust = drops.iter().find(|d| d.group == "rust").unwrap();
        assert_eq!(rust.items_dropped, 4);
        assert!(rust.top_changed, "dropping rust must unseat A");
        let node = drops.iter().find(|d| d.group == "node").unwrap();
        assert!(!node.top_changed);
    }

    #[test]
    fn item_influence_ranks_the_decisive_task_first() {
        // Two rounds tie on nine items; item t00 alone decides it.
        let mut a = vec![0.5; 10];
        let mut b = vec![0.5; 10];
        a[0] = 1.0;
        b[0] = 0.0;
        let m = matrix(&[("A", &a), ("B", &b)]);
        let inf = item_influence(&m);
        assert_eq!(inf[0].item, "t00");
        assert!(inf[0].top_gap_delta < 0.0, "removing it must shrink the gap");
        // Removing a neutral item leaves the verdict alone; it only nudges
        // the gap by re-weighting the decisive one across a shorter corpus.
        let worst_neutral = inf[1..]
            .iter()
            .map(|i| i.top_gap_delta.abs())
            .fold(0.0f64, f64::max);
        assert!(
            worst_neutral < inf[0].top_gap_delta.abs() / 5.0,
            "neutral items moved the gap by {worst_neutral}"
        );
        assert!(inf[1..].iter().all(|i| !i.flips_top));
    }

    #[test]
    fn rule_agreement_flags_a_weighting_dependent_verdict() {
        let reference = matrix(&[("A", &[1.0, 0.0, 0.6]), ("B", &[0.0, 1.0, 0.5])]);
        let strict = matrix(&[("A", &[1.0, 0.0, 0.0]), ("B", &[0.0, 1.0, 1.0])]);
        let same = matrix(&[("A", &[1.0, 0.1, 0.7]), ("B", &[0.0, 1.0, 0.5])]);
        let out = rule_agreement(&reference, &[("strict".into(), strict), ("similar".into(), same)]);
        let strict = out.iter().find(|r| r.rule == "strict").unwrap();
        assert_eq!(strict.top.as_deref(), Some("B"));
        assert!(!strict.order_matches_reference);
        let similar = out.iter().find(|r| r.rule == "similar").unwrap();
        assert_eq!(similar.top.as_deref(), Some("A"));
        assert!(similar.order_matches_reference);
    }
}
