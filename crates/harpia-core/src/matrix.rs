// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//! The score matrix every meta-evaluation reads: subjects (rounds) by items
//! (tasks), one capability score per cell.
//!
//! Missing cells are real — rounds cover different corpora, and a cancelled
//! round covers part of one. They are held as `f64::NAN` and never silently
//! read as zero, because "not attempted" and "attempted and failed" are the
//! two things a benchmark must never confuse.

use std::collections::BTreeMap;

#[derive(Debug, Clone, Default)]
pub struct ScoreMatrix {
    pub subjects: Vec<String>,
    pub items: Vec<String>,
    /// `scores[subject][item]`, `NaN` where the subject has no measurement.
    pub scores: Vec<Vec<f64>>,
}

impl ScoreMatrix {
    pub fn new(subjects: Vec<String>, items: Vec<String>) -> Self {
        let scores = vec![vec![f64::NAN; items.len()]; subjects.len()];
        Self { subjects, items, scores }
    }

    /// Build from (subject, item, score) triples; later writes win.
    pub fn from_triples<I: IntoIterator<Item = (String, String, f64)>>(triples: I) -> Self {
        let rows: Vec<(String, String, f64)> = triples.into_iter().collect();
        let mut subjects: Vec<String> = rows.iter().map(|(s, _, _)| s.clone()).collect();
        subjects.dedup();
        let mut seen = BTreeMap::new();
        let mut subject_order = Vec::new();
        for s in subjects {
            if seen.insert(s.clone(), ()).is_none() {
                subject_order.push(s);
            }
        }
        let mut item_order: Vec<String> = rows.iter().map(|(_, i, _)| i.clone()).collect();
        item_order.sort();
        item_order.dedup();
        let mut m = ScoreMatrix::new(subject_order, item_order);
        for (s, i, v) in rows {
            let (Some(si), Some(ii)) = (m.subject_index(&s), m.item_index(&i)) else { continue };
            m.scores[si][ii] = v;
        }
        m
    }

    pub fn subject_index(&self, s: &str) -> Option<usize> {
        self.subjects.iter().position(|x| x == s)
    }

    pub fn item_index(&self, i: &str) -> Option<usize> {
        self.items.iter().position(|x| x == i)
    }

    pub fn n_subjects(&self) -> usize {
        self.subjects.len()
    }

    pub fn n_items(&self) -> usize {
        self.items.len()
    }

    /// Column indices measured by every subject — the complete-case set that
    /// reliability and rank-stability work on.
    pub fn complete_items(&self) -> Vec<usize> {
        (0..self.n_items())
            .filter(|&j| self.scores.iter().all(|row| row[j].is_finite()))
            .collect()
    }

    /// A dense sub-matrix over the given columns, in subject order.
    pub fn dense(&self, items: &[usize]) -> Vec<Vec<f64>> {
        self.scores
            .iter()
            .map(|row| items.iter().map(|&j| row[j]).collect())
            .collect()
    }

    /// Every finite score a subject has, in item order.
    pub fn subject_scores(&self, si: usize) -> Vec<f64> {
        self.scores[si].iter().copied().filter(|v| v.is_finite()).collect()
    }

    /// Every finite score recorded for one item, across subjects.
    pub fn item_scores(&self, ii: usize) -> Vec<f64> {
        self.scores
            .iter()
            .map(|row| row[ii])
            .filter(|v| v.is_finite())
            .collect()
    }

    /// Keep only the named items (used by leave-one-stack-out).
    pub fn without_items(&self, drop: &[usize]) -> ScoreMatrix {
        let keep: Vec<usize> = (0..self.n_items()).filter(|j| !drop.contains(j)).collect();
        ScoreMatrix {
            subjects: self.subjects.clone(),
            items: keep.iter().map(|&j| self.items[j].clone()).collect(),
            scores: self.dense(&keep),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn m() -> ScoreMatrix {
        ScoreMatrix::from_triples([
            ("a".into(), "t1".into(), 1.0),
            ("a".into(), "t2".into(), 0.0),
            ("b".into(), "t1".into(), 0.5),
            // b never attempted t2
        ])
    }

    #[test]
    fn missing_cells_are_nan_not_zero() {
        let m = m();
        assert_eq!(m.n_subjects(), 2);
        assert_eq!(m.n_items(), 2);
        let bi = m.subject_index("b").unwrap();
        let t2 = m.item_index("t2").unwrap();
        assert!(m.scores[bi][t2].is_nan());
        assert_eq!(m.complete_items(), vec![m.item_index("t1").unwrap()]);
    }

    #[test]
    fn item_and_subject_views_skip_missing() {
        let m = m();
        assert_eq!(m.item_scores(m.item_index("t2").unwrap()), vec![0.0]);
        assert_eq!(m.subject_scores(m.subject_index("b").unwrap()), vec![0.5]);
    }

    #[test]
    fn without_items_drops_columns() {
        let m = m();
        let t1 = m.item_index("t1").unwrap();
        let reduced = m.without_items(&[t1]);
        assert_eq!(reduced.items, vec!["t2".to_string()]);
        assert_eq!(reduced.scores[0], vec![0.0]);
    }
}
