// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//! Read and write paths for meta-evaluation: the rows a report needs to
//! judge the benchmark rather than the harnesses.
//!
//! Everything here is a thin, typed view over SQL. The arithmetic lives in
//! `harpia-core` and the prose in `harpia-report`; this module's only job is
//! to hand them complete rows, with "not measured" preserved as `None` all
//! the way through.

use crate::Store;
use anyhow::Result;
use harpia_core::metrics::{Fault, ProxyUsage, TelemetrySource};
use rusqlite::{params, OptionalExtension};

/// A round as the meta-reports read it: identity plus every knob that was
/// turned, so two rounds can be told apart by design rather than by label.
#[derive(Debug, Clone)]
pub struct RoundRow {
    pub id: i64,
    pub label: String,
    pub harness_id: String,
    pub model: String,
    pub effort: Option<String>,
    pub tasks_sha: String,
    pub jobs: Option<u32>,
    pub corpus_size: Option<u32>,
    pub order_seed: Option<i64>,
    pub budget_scale: Option<f64>,
    pub prompt_variant: Option<u32>,
    pub oracles_visible: bool,
    pub toolchain: Option<String>,
    pub started_epoch: Option<i64>,
    pub finished_epoch: Option<i64>,
}

impl RoundRow {
    /// Rounds that differ only in one knob are an experiment; rounds that
    /// differ in several are a confound. This is the tuple the sensitivity
    /// reports group by.
    pub fn design_key(&self) -> (String, String, Option<String>, String) {
        (
            self.harness_id.clone(),
            self.model.clone(),
            self.effort.clone(),
            self.tasks_sha.clone(),
        )
    }

    pub fn budget_scale_or_default(&self) -> f64 {
        self.budget_scale.unwrap_or(1.0)
    }
}

#[derive(Debug, Clone)]
pub struct TaskRow {
    pub id: String,
    pub stack: String,
    pub tier: String,
    pub family: Option<String>,
    pub content_sha: Option<String>,
}

/// Per-trial provenance, keyed by trial id so a report can join it onto the
/// scored rows without a second pass over oracles.
#[derive(Debug, Clone)]
pub struct TrialMeta {
    pub trial_id: i64,
    pub task_id: String,
    pub attempt: u32,
    pub session_id: Option<String>,
    pub prompt_variant: u32,
    pub telemetry_source: TelemetrySource,
    pub proxy: ProxyUsage,
    pub fault: Fault,
    pub task_content_sha: Option<String>,
    pub cost_usd: Option<f64>,
}

/// One trial's oracle verdicts, the substrate every alternative scoring rule
/// is recomputed from.
#[derive(Debug, Clone)]
pub struct TrialOracles {
    pub trial_id: i64,
    pub task_id: String,
    pub attempt: u32,
    pub verdicts: Vec<OracleVerdictRow>,
}

#[derive(Debug, Clone)]
pub struct OracleVerdictRow {
    pub kind: String,
    pub passed: bool,
    pub weight: f64,
}

#[derive(Debug, Clone)]
pub struct AuditRow {
    pub at_epoch: i64,
    pub task_id: String,
    pub content_sha: Option<String>,
    pub kind: String,
    pub operator: String,
    pub target: String,
    pub expected: String,
    pub observed: f64,
    pub passed: bool,
    pub detail: Option<String>,
}

#[derive(Debug, Clone)]
pub struct CorpusCheckRow {
    pub at_epoch: i64,
    pub task_id: String,
    pub content_sha: Option<String>,
    pub solution_capability: f64,
    pub starter_capability: f64,
    pub ok: bool,
    pub toolchain: Option<String>,
}

#[derive(Debug, Clone)]
pub struct ContaminationRow {
    pub task_id: String,
    pub at_epoch: i64,
    pub canary: Option<String>,
    pub canary_unique: Option<bool>,
    pub max_similarity: Option<f64>,
    pub nearest_source: Option<String>,
    pub corpus_label: Option<String>,
}

impl Store {
    // ---- rounds and tasks ----

    pub fn rounds(&self) -> Result<Vec<RoundRow>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, label, harness_id, model, effort, tasks_sha, jobs, corpus_size,
                    order_seed, budget_scale, prompt_variant, oracles_visible, toolchain,
                    started_epoch, finished_epoch
             FROM round ORDER BY id",
        )?;
        let rows = stmt.query_map([], |r| {
            Ok(RoundRow {
                id: r.get(0)?,
                label: r.get(1)?,
                harness_id: r.get(2)?,
                model: r.get(3)?,
                effort: r.get(4)?,
                tasks_sha: r.get(5)?,
                jobs: r.get(6)?,
                corpus_size: r.get(7)?,
                order_seed: r.get(8)?,
                budget_scale: r.get(9)?,
                prompt_variant: r.get(10)?,
                oracles_visible: r.get::<_, Option<i64>>(11)?.unwrap_or(0) != 0,
                toolchain: r.get(12)?,
                started_epoch: r.get(13)?,
                finished_epoch: r.get(14)?,
            })
        })?;
        Ok(rows.collect::<rusqlite::Result<_>>()?)
    }

    pub fn round_row(&self, round_id: i64) -> Result<Option<RoundRow>> {
        Ok(self.rounds()?.into_iter().find(|r| r.id == round_id))
    }

    pub fn tasks(&self) -> Result<Vec<TaskRow>> {
        let mut stmt = self
            .conn
            .prepare("SELECT id, stack, tier, family, content_sha FROM task ORDER BY id")?;
        let rows = stmt.query_map([], |r| {
            Ok(TaskRow {
                id: r.get(0)?,
                stack: r.get(1)?,
                tier: r.get(2)?,
                family: r.get(3)?,
                content_sha: r.get(4)?,
            })
        })?;
        Ok(rows.collect::<rusqlite::Result<_>>()?)
    }

    // ---- per-trial provenance ----

    pub fn trial_meta(&self, round_id: i64) -> Result<Vec<TrialMeta>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, task_id, attempt, session_id, prompt_variant, telemetry_source,
                    proxy_input_tokens, proxy_output_tokens, proxy_cache_read_tokens,
                    proxy_cache_write_tokens, proxy_requests, fault, task_content_sha, cost_usd
             FROM trial WHERE round_id = ?1 ORDER BY task_id, attempt",
        )?;
        let rows = stmt.query_map(params![round_id], |r| {
            let src: Option<String> = r.get(5)?;
            let fault: Option<String> = r.get(11)?;
            Ok(TrialMeta {
                trial_id: r.get(0)?,
                task_id: r.get(1)?,
                attempt: r.get(2)?,
                session_id: r.get(3)?,
                prompt_variant: r.get::<_, Option<u32>>(4)?.unwrap_or(0),
                telemetry_source: src
                    .as_deref()
                    .and_then(TelemetrySource::parse)
                    .unwrap_or(TelemetrySource::Missing),
                proxy: ProxyUsage {
                    input_tokens: r.get::<_, Option<u64>>(6)?.unwrap_or(0),
                    output_tokens: r.get::<_, Option<u64>>(7)?.unwrap_or(0),
                    cache_read_tokens: r.get::<_, Option<u64>>(8)?.unwrap_or(0),
                    cache_write_tokens: r.get::<_, Option<u64>>(9)?.unwrap_or(0),
                    requests: r.get::<_, Option<u64>>(10)?.unwrap_or(0),
                },
                fault: fault.as_deref().and_then(Fault::parse).unwrap_or(Fault::None),
                task_content_sha: r.get(12)?,
                cost_usd: r.get(13)?,
            })
        })?;
        Ok(rows.collect::<rusqlite::Result<_>>()?)
    }

    /// Every oracle verdict of a round, grouped by trial. Alternative scoring
    /// rules are recomputed from these rather than from stored scores — a
    /// stored score already contains the weighting under test.
    pub fn round_oracles(&self, round_id: i64) -> Result<Vec<TrialOracles>> {
        let mut stmt = self.conn.prepare(
            "SELECT t.id, t.task_id, t.attempt, o.kind, o.passed, o.weight
             FROM trial t JOIN oracle_result o ON o.trial_id = t.id
             WHERE t.round_id = ?1
             ORDER BY t.task_id, t.attempt, o.oracle_idx",
        )?;
        let rows = stmt.query_map(params![round_id], |r| {
            Ok((
                r.get::<_, i64>(0)?,
                r.get::<_, String>(1)?,
                r.get::<_, u32>(2)?,
                OracleVerdictRow {
                    kind: r.get(3)?,
                    passed: r.get(4)?,
                    weight: r.get(5)?,
                },
            ))
        })?;
        let mut out: Vec<TrialOracles> = Vec::new();
        for row in rows {
            let (trial_id, task_id, attempt, verdict) = row?;
            match out.last_mut() {
                Some(last) if last.trial_id == trial_id => last.verdicts.push(verdict),
                _ => out.push(TrialOracles {
                    trial_id,
                    task_id,
                    attempt,
                    verdicts: vec![verdict],
                }),
            }
        }
        Ok(out)
    }

    // ---- oracle audit ----

    #[allow(clippy::too_many_arguments)]
    pub fn record_oracle_audit(&self, row: &AuditRow) -> Result<()> {
        self.conn.execute(
            "INSERT INTO oracle_audit (at_epoch, task_id, content_sha, kind, operator,
                target, expected, observed, passed, detail)
             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10)",
            params![
                row.at_epoch,
                row.task_id,
                row.content_sha,
                row.kind,
                row.operator,
                row.target,
                row.expected,
                row.observed,
                row.passed,
                row.detail
            ],
        )?;
        Ok(())
    }

    /// Audit rows, newest run first. `only_latest` keeps one row per
    /// (task, kind, operator, target) so a re-audit supersedes rather than
    /// dilutes the previous verdict.
    pub fn oracle_audits(&self, only_latest: bool) -> Result<Vec<AuditRow>> {
        let sql = if only_latest {
            "SELECT at_epoch, task_id, content_sha, kind, operator, target, expected,
                    observed, passed, detail
             FROM oracle_audit
             WHERE id IN (SELECT MAX(id) FROM oracle_audit GROUP BY task_id, kind, operator, target)
             ORDER BY task_id, kind, operator"
        } else {
            "SELECT at_epoch, task_id, content_sha, kind, operator, target, expected,
                    observed, passed, detail
             FROM oracle_audit ORDER BY task_id, kind, operator"
        };
        let mut stmt = self.conn.prepare(sql)?;
        let rows = stmt.query_map([], |r| {
            Ok(AuditRow {
                at_epoch: r.get(0)?,
                task_id: r.get(1)?,
                content_sha: r.get(2)?,
                kind: r.get(3)?,
                operator: r.get(4)?,
                target: r.get(5)?,
                expected: r.get(6)?,
                observed: r.get(7)?,
                passed: r.get(8)?,
                detail: r.get(9)?,
            })
        })?;
        Ok(rows.collect::<rusqlite::Result<_>>()?)
    }

    // ---- corpus validation history ----

    pub fn record_corpus_check(&self, row: &CorpusCheckRow) -> Result<()> {
        self.conn.execute(
            "INSERT INTO corpus_check (at_epoch, task_id, content_sha, solution_capability,
                starter_capability, ok, toolchain)
             VALUES (?1,?2,?3,?4,?5,?6,?7)",
            params![
                row.at_epoch,
                row.task_id,
                row.content_sha,
                row.solution_capability,
                row.starter_capability,
                row.ok,
                row.toolchain
            ],
        )?;
        Ok(())
    }

    pub fn corpus_checks(&self) -> Result<Vec<CorpusCheckRow>> {
        let mut stmt = self.conn.prepare(
            "SELECT at_epoch, task_id, content_sha, solution_capability, starter_capability,
                    ok, toolchain
             FROM corpus_check ORDER BY at_epoch, task_id",
        )?;
        let rows = stmt.query_map([], |r| {
            Ok(CorpusCheckRow {
                at_epoch: r.get(0)?,
                task_id: r.get(1)?,
                content_sha: r.get(2)?,
                solution_capability: r.get(3)?,
                starter_capability: r.get(4)?,
                ok: r.get(5)?,
                toolchain: r.get(6)?,
            })
        })?;
        Ok(rows.collect::<rusqlite::Result<_>>()?)
    }

    /// The two most recent validation sweeps, so drift is a diff rather than
    /// a reading exercise.
    pub fn latest_two_check_epochs(&self) -> Result<Vec<i64>> {
        let mut stmt = self
            .conn
            .prepare("SELECT DISTINCT at_epoch FROM corpus_check ORDER BY at_epoch DESC LIMIT 2")?;
        let rows = stmt.query_map([], |r| r.get(0))?;
        Ok(rows.collect::<rusqlite::Result<_>>()?)
    }

    // ---- contamination ----

    pub fn record_contamination(&self, row: &ContaminationRow) -> Result<()> {
        self.conn.execute(
            "INSERT INTO contamination (task_id, at_epoch, canary, canary_unique,
                max_similarity, nearest_source, corpus_label)
             VALUES (?1,?2,?3,?4,?5,?6,?7)
             ON CONFLICT(task_id) DO UPDATE SET at_epoch = ?2, canary = ?3,
                canary_unique = ?4, max_similarity = ?5, nearest_source = ?6,
                corpus_label = ?7",
            params![
                row.task_id,
                row.at_epoch,
                row.canary,
                row.canary_unique,
                row.max_similarity,
                row.nearest_source,
                row.corpus_label
            ],
        )?;
        Ok(())
    }

    pub fn contamination_rows(&self) -> Result<Vec<ContaminationRow>> {
        let mut stmt = self.conn.prepare(
            "SELECT task_id, at_epoch, canary, canary_unique, max_similarity,
                    nearest_source, corpus_label
             FROM contamination ORDER BY task_id",
        )?;
        let rows = stmt.query_map([], |r| {
            Ok(ContaminationRow {
                task_id: r.get(0)?,
                at_epoch: r.get(1)?,
                canary: r.get(2)?,
                canary_unique: r.get::<_, Option<i64>>(3)?.map(|v| v != 0),
                max_similarity: r.get(4)?,
                nearest_source: r.get(5)?,
                corpus_label: r.get(6)?,
            })
        })?;
        Ok(rows.collect::<rusqlite::Result<_>>()?)
    }

    /// Harness version string, for the report identity block.
    pub fn harness_version(&self, harness_id: &str) -> Result<Option<String>> {
        Ok(self
            .conn
            .query_row(
                "SELECT harness_version FROM harness WHERE id = ?1",
                params![harness_id],
                |r| r.get(0),
            )
            .optional()?
            .flatten())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{RoundStart, TrialProvenance, TrialRecord};
    use harpia_core::metrics::{Outcome, Telemetry};

    fn store() -> Store {
        let s = Store::open_in_memory().unwrap();
        s.upsert_harness("h", "0", None, "").unwrap();
        s.upsert_task_full("t1", "rust", "simple", "T1", "", Some("sha-a"), Some("build"))
            .unwrap();
        s
    }

    #[test]
    fn round_knobs_round_trip() {
        let s = store();
        let id = s
            .begin_round_full(&RoundStart {
                label: "budget-2x",
                harness_id: "h",
                model: "m",
                tasks_sha: "corpus1",
                started_at: "now",
                jobs: Some(4),
                order_seed: Some(99),
                budget_scale: Some(2.0),
                prompt_variant: Some(1),
                oracles_visible: Some(true),
                toolchain: Some("{\"rustc\":\"1.97.1\"}"),
                ..Default::default()
            })
            .unwrap();
        let r = s.round_row(id).unwrap().unwrap();
        assert_eq!(r.order_seed, Some(99));
        assert_eq!(r.budget_scale_or_default(), 2.0);
        assert_eq!(r.prompt_variant, Some(1));
        assert!(r.oracles_visible);
        assert!(r.toolchain.unwrap().contains("1.97.1"));
        // A legacy round has no knobs recorded and must read as standard.
        let legacy = s.begin_round("legacy", "h", "m", None, "corpus1", "now").unwrap();
        let l = s.round_row(legacy).unwrap().unwrap();
        assert_eq!(l.budget_scale_or_default(), 1.0);
        assert!(!l.oracles_visible);
    }

    #[test]
    fn trial_provenance_round_trips() {
        let mut s = store();
        let round = s.begin_round("r", "h", "m", None, "corpus1", "now").unwrap();
        let t = Telemetry { requests: 3, ..Default::default() };
        s.record_trial(&TrialRecord {
            round_id: round,
            task_id: "t1",
            attempt: 1,
            outcome: Outcome::Crashed,
            telemetry: &t,
            diff_stat: None,
            oracles: &[("hidden-tests".into(), false, 2.0, None)],
            tools: &[],
            model_calls: &[],
            started_epoch: None,
            finished_epoch: None,
            rung: None,
            steps: None,
            stop_reason: None,
            provenance: TrialProvenance {
                fault: Fault::Infra,
                telemetry_source: TelemetrySource::Both,
                proxy: Some(ProxyUsage { input_tokens: 500, requests: 3, ..Default::default() }),
                prompt_variant: 2,
                task_content_sha: Some("sha-a"),
                session_id: Some("sess-1"),
            },
        })
        .unwrap();

        let meta = s.trial_meta(round).unwrap();
        assert_eq!(meta.len(), 1);
        let m = &meta[0];
        assert_eq!(m.fault, Fault::Infra);
        assert_eq!(m.telemetry_source, TelemetrySource::Both);
        assert_eq!(m.proxy.input_tokens, 500);
        assert_eq!(m.prompt_variant, 2);
        assert_eq!(m.session_id.as_deref(), Some("sess-1"));
        assert_eq!(m.task_content_sha.as_deref(), Some("sha-a"));

        // And the scored view carries the same fault and hash.
        let rows = s.round_trials(round).unwrap();
        assert_eq!(rows[0].fault, Fault::Infra);
        assert_eq!(rows[0].task_content_sha.as_deref(), Some("sha-a"));

        let oracles = s.round_oracles(round).unwrap();
        assert_eq!(oracles.len(), 1);
        assert_eq!(oracles[0].verdicts.len(), 1);
        assert_eq!(oracles[0].verdicts[0].weight, 2.0);
    }

    #[test]
    fn audit_latest_supersedes_earlier_verdicts() {
        let s = store();
        let mut row = AuditRow {
            at_epoch: 100,
            task_id: "t1".into(),
            content_sha: Some("sha-a".into()),
            kind: "mutation".into(),
            operator: "flip-comparison".into(),
            target: "src/lib.rs".into(),
            expected: "fail".into(),
            observed: 1.0,
            passed: false,
            detail: Some("mutant survived".into()),
        };
        s.record_oracle_audit(&row).unwrap();
        row.at_epoch = 200;
        row.observed = 0.0;
        row.passed = true;
        row.detail = None;
        s.record_oracle_audit(&row).unwrap();

        assert_eq!(s.oracle_audits(false).unwrap().len(), 2);
        let latest = s.oracle_audits(true).unwrap();
        assert_eq!(latest.len(), 1);
        assert!(latest[0].passed);
    }

    #[test]
    fn corpus_checks_and_contamination_persist() {
        let s = store();
        s.record_corpus_check(&CorpusCheckRow {
            at_epoch: 10,
            task_id: "t1".into(),
            content_sha: Some("sha-a".into()),
            solution_capability: 1.0,
            starter_capability: 0.0,
            ok: true,
            toolchain: Some("{}".into()),
        })
        .unwrap();
        s.record_corpus_check(&CorpusCheckRow {
            at_epoch: 20,
            task_id: "t1".into(),
            content_sha: Some("sha-a".into()),
            solution_capability: 0.5,
            starter_capability: 0.0,
            ok: false,
            toolchain: Some("{}".into()),
        })
        .unwrap();
        assert_eq!(s.latest_two_check_epochs().unwrap(), vec![20, 10]);
        assert_eq!(s.corpus_checks().unwrap().len(), 2);

        s.record_contamination(&ContaminationRow {
            task_id: "t1".into(),
            at_epoch: 30,
            canary: Some("HARPIA-CANARY-t1".into()),
            canary_unique: Some(true),
            max_similarity: Some(0.12),
            nearest_source: Some("public/foo.rs".into()),
            corpus_label: Some("swe-corpus".into()),
        })
        .unwrap();
        let rows = s.contamination_rows().unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].canary_unique, Some(true));
        assert!((rows[0].max_similarity.unwrap() - 0.12).abs() < 1e-12);
    }
}
