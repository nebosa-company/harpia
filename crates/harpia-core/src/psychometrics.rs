//! Item analysis: does each task still carry information?
//!
//! A benchmark's headline number is a mean over items, and a mean over items
//! is only as meaningful as the items. A task every harness solves and a task
//! no harness solves both contribute variance zero: they pad `n` without
//! adding evidence, which inflates confidence in exactly the way a
//! confidence interval is supposed to prevent. This module names those items,
//! measures how well each one ranks harnesses the way the corpus as a whole
//! does, and reports the reliability that any claimed gap rests on.

use crate::matrix::ScoreMatrix;
use crate::stats;
use serde::Serialize;

/// A task is "solved" when it clears every non-security oracle.
pub const SOLVED: f64 = 1.0;

#[derive(Debug, Clone, Serialize)]
pub struct ItemStat {
    pub item: String,
    /// Subjects (rounds) that actually attempted it.
    pub n: usize,
    /// Mean score — the classical difficulty index `p`. Low = hard.
    pub difficulty: f64,
    pub solve_rate: f64,
    pub sd: f64,
    /// Corrected item-total correlation: this item against the sum of the
    /// others. `None` when the item is constant or too few subjects exist.
    pub discrimination: Option<f64>,
    /// Every subject scored it 1.0.
    pub ceiling: bool,
    /// Every subject scored it 0.0.
    pub floor: bool,
    /// Constant across subjects: contributes no ranking information.
    pub dead: bool,
    /// Ranks harnesses backwards relative to the rest of the corpus.
    pub negative_discrimination: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct Reliability {
    pub n_subjects: usize,
    pub n_items: usize,
    /// Cronbach's alpha over complete cases.
    pub alpha: Option<f64>,
    /// Odd/even split-half, Spearman-Brown corrected.
    pub split_half: Option<f64>,
    /// Spread of subject total scores (the scale alpha is relative to).
    pub sd_total: f64,
    /// Standard error of measurement on the 0..1 capability scale.
    pub sem: Option<f64>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ItemAnalysis {
    pub items: Vec<ItemStat>,
    pub n_subjects: usize,
    pub n_items: usize,
    /// Items with any variance across subjects — the ones doing the work.
    pub live_items: usize,
    pub dead_items: usize,
    pub ceiling_items: usize,
    pub floor_items: usize,
    pub negative_items: usize,
    /// Items every subject attempted; reliability is computed on these.
    pub complete_items: usize,
    pub reliability: Option<Reliability>,
}

impl ItemAnalysis {
    /// The `n` a confidence interval is entitled to use. Reporting `n = 260`
    /// when 90 of those items separate nobody overstates the evidence.
    pub fn effective_n(&self) -> usize {
        self.live_items
    }
}

/// Per-item statistics plus corpus-level reliability.
pub fn analyze(m: &ScoreMatrix) -> ItemAnalysis {
    let n_subjects = m.n_subjects();
    let complete = m.complete_items();
    let dense = m.dense(&complete);

    let mut items = Vec::with_capacity(m.n_items());
    for (j, name) in m.items.iter().enumerate() {
        let col = m.item_scores(j);
        let n = col.len();
        let difficulty = stats::mean(&col);
        let solve_rate = if n == 0 {
            0.0
        } else {
            col.iter().filter(|&&v| v >= SOLVED).count() as f64 / n as f64
        };
        let sd = stats::sd(&col);
        let discrimination = corrected_item_total(m, j);
        let ceiling = n > 0 && col.iter().all(|&v| v >= SOLVED);
        let floor = n > 0 && col.iter().all(|&v| v <= 0.0);
        let dead = n > 0 && sd == 0.0;
        items.push(ItemStat {
            item: name.clone(),
            n,
            difficulty,
            solve_rate,
            sd,
            discrimination,
            ceiling,
            floor,
            dead,
            negative_discrimination: discrimination.is_some_and(|r| r < 0.0),
        });
    }

    let reliability = (n_subjects >= 2 && complete.len() >= 2).then(|| {
        let totals: Vec<f64> = dense.iter().map(|r| stats::mean(r)).collect();
        let sd_total = stats::sd(&totals);
        let alpha = stats::cronbach_alpha(&dense);
        Reliability {
            n_subjects,
            n_items: complete.len(),
            alpha,
            split_half: stats::split_half_reliability(&dense),
            sd_total,
            sem: alpha.map(|a| stats::sem(sd_total, a)),
        }
    });

    ItemAnalysis {
        n_subjects,
        n_items: m.n_items(),
        live_items: items.iter().filter(|i| !i.dead && i.n > 0).count(),
        dead_items: items.iter().filter(|i| i.dead).count(),
        ceiling_items: items.iter().filter(|i| i.ceiling).count(),
        floor_items: items.iter().filter(|i| i.floor).count(),
        negative_items: items.iter().filter(|i| i.negative_discrimination).count(),
        complete_items: complete.len(),
        items,
        reliability,
    }
}

/// Correlation of one item against the mean of all *other* items, over the
/// subjects that attempted it. Uncorrected item-total correlation is
/// self-inflating — the item is part of its own total — and with a corpus
/// this small the inflation is not cosmetic.
fn corrected_item_total(m: &ScoreMatrix, item: usize) -> Option<f64> {
    let mut xs = Vec::new();
    let mut ys = Vec::new();
    for (si, row) in m.scores.iter().enumerate() {
        let v = row[item];
        if !v.is_finite() {
            continue;
        }
        let rest: Vec<f64> = row
            .iter()
            .enumerate()
            .filter(|(j, x)| *j != item && x.is_finite())
            .map(|(_, x)| *x)
            .collect();
        if rest.is_empty() {
            continue;
        }
        let _ = si;
        xs.push(v);
        ys.push(stats::mean(&rest));
    }
    stats::pearson(&xs, &ys)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn matrix(rows: &[(&str, &[f64])], items: &[&str]) -> ScoreMatrix {
        let mut triples = Vec::new();
        for (subject, scores) in rows {
            for (j, s) in scores.iter().enumerate() {
                triples.push((subject.to_string(), items[j].to_string(), *s));
            }
        }
        ScoreMatrix::from_triples(triples)
    }

    #[test]
    fn dead_items_are_named() {
        let m = matrix(
            &[
                ("r1", &[1.0, 0.0, 1.0, 0.3]),
                ("r2", &[1.0, 0.0, 0.0, 0.7]),
                ("r3", &[1.0, 0.0, 1.0, 0.9]),
            ],
            &["everyone-solves", "nobody-solves", "splits", "partial"],
        );
        let a = analyze(&m);
        assert_eq!(a.n_items, 4);
        assert_eq!(a.dead_items, 2);
        assert_eq!(a.ceiling_items, 1);
        assert_eq!(a.floor_items, 1);
        assert_eq!(a.live_items, 2);
        assert_eq!(a.effective_n(), 2);
        let ceiling = a.items.iter().find(|i| i.item == "everyone-solves").unwrap();
        assert!(ceiling.dead && ceiling.ceiling);
        assert!(ceiling.discrimination.is_none(), "a constant item cannot correlate");
    }

    #[test]
    fn discrimination_is_signed() {
        // t_good agrees with the corpus ordering; t_bad reverses it.
        let m = matrix(
            &[
                ("weak", &[0.0, 1.0, 0.0, 0.0]),
                ("mid", &[0.5, 0.5, 0.5, 0.5]),
                ("strong", &[1.0, 0.0, 1.0, 1.0]),
            ],
            &["t_good", "t_bad", "f1", "f2"],
        );
        let a = analyze(&m);
        let good = a.items.iter().find(|i| i.item == "t_good").unwrap();
        let bad = a.items.iter().find(|i| i.item == "t_bad").unwrap();
        assert!(good.discrimination.unwrap() > 0.9, "{:?}", good.discrimination);
        assert!(bad.discrimination.unwrap() < -0.9, "{:?}", bad.discrimination);
        assert_eq!(a.negative_items, 1);
    }

    #[test]
    fn reliability_reported_on_complete_cases_only() {
        let mut triples = Vec::new();
        for (s, base) in [("r1", 0.1), ("r2", 0.5), ("r3", 0.9)] {
            for j in 0..6 {
                triples.push((s.to_string(), format!("t{j}"), (base + j as f64 * 0.01).min(1.0)));
            }
        }
        // A seventh item only one round attempted.
        triples.push(("r1".into(), "t6".into(), 1.0));
        let m = ScoreMatrix::from_triples(triples);
        let a = analyze(&m);
        assert_eq!(a.n_items, 7);
        assert_eq!(a.complete_items, 6);
        let rel = a.reliability.unwrap();
        assert_eq!(rel.n_items, 6);
        assert!(rel.alpha.unwrap() > 0.95, "alpha = {:?}", rel.alpha);
        assert!(rel.sem.unwrap() < 0.1);
    }

    #[test]
    fn single_subject_has_no_reliability() {
        let m = matrix(&[("only", &[1.0, 0.0, 0.5])], &["a", "b", "c"]);
        let a = analyze(&m);
        assert!(a.reliability.is_none());
        // With one subject every item looks constant; that is a fact about
        // the evidence, not about the items.
        assert_eq!(a.dead_items, 3);
    }
}
