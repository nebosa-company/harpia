//! SQLite persistence for Harpia. One file per bench database; WAL mode;
//! every write inside a transaction so a killed run never corrupts a round.

use anyhow::{Context, Result};
use harpia_core::metrics::{Outcome, Telemetry};
use harpia_core::scoring::{self, OracleVerdict};
use rusqlite::{params, Connection};
use std::collections::HashSet;
use std::path::Path;

pub const SCHEMA: &str = include_str!("schema.sql");

pub struct Store {
    pub conn: Connection,
}

/// Everything one finished trial writes, in one transaction.
pub struct TrialRecord<'a> {
    pub round_id: i64,
    pub task_id: &'a str,
    pub attempt: u32,
    pub outcome: Outcome,
    pub telemetry: &'a Telemetry,
    pub diff_stat: Option<&'a str>,
    /// (kind, passed, weight, detail) in oracle order. kind "security" feeds
    /// the security score; everything else feeds capability.
    pub oracles: &'a [(String, bool, f64, Option<String>)],
    /// (tool name, ok) in call order.
    pub tools: &'a [(String, bool)],
}

/// A trial as the report side reads it: telemetry plus derived scores.
#[derive(Debug, Clone)]
pub struct TrialRow {
    pub id: i64,
    pub task_id: String,
    pub attempt: u32,
    pub outcome: Outcome,
    pub telemetry: Telemetry,
    pub capability: f64,
    pub security: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Price {
    pub input_per_mtok: f64,
    pub output_per_mtok: f64,
    pub cache_read_per_mtok: f64,
    pub cache_write_per_mtok: f64,
}

impl Price {
    pub fn cost(&self, t: &Telemetry) -> f64 {
        (t.input_tokens as f64 * self.input_per_mtok
            + t.output_tokens as f64 * self.output_per_mtok
            + t.cache_read_tokens as f64 * self.cache_read_per_mtok
            + t.cache_write_tokens as f64 * self.cache_write_per_mtok)
            / 1_000_000.0
    }
}

impl Store {
    pub fn open(path: &Path) -> Result<Self> {
        let conn = Connection::open(path)?;
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;
        conn.pragma_update(None, "foreign_keys", "ON")?;
        conn.execute_batch(SCHEMA)?;
        Ok(Self { conn })
    }

    pub fn open_in_memory() -> Result<Self> {
        let conn = Connection::open_in_memory()?;
        conn.pragma_update(None, "foreign_keys", "ON")?;
        conn.execute_batch(SCHEMA)?;
        Ok(Self { conn })
    }

    // ---- write path ----

    pub fn upsert_harness(&self, id: &str, version: &str, manifest: &str) -> Result<()> {
        self.conn.execute(
            "INSERT INTO harness (id, version, manifest) VALUES (?1, ?2, ?3)
             ON CONFLICT(id) DO UPDATE SET version = ?2, manifest = ?3",
            params![id, version, manifest],
        )?;
        Ok(())
    }

    pub fn upsert_task(&self, id: &str, stack: &str, tier: &str, title: &str, spec: &str) -> Result<()> {
        self.conn.execute(
            "INSERT INTO task (id, stack, tier, title, spec) VALUES (?1, ?2, ?3, ?4, ?5)
             ON CONFLICT(id) DO UPDATE SET stack = ?2, tier = ?3, title = ?4, spec = ?5",
            params![id, stack, tier, title, spec],
        )?;
        Ok(())
    }

    pub fn begin_round(
        &self,
        label: &str,
        harness_id: &str,
        model: &str,
        effort: Option<&str>,
        tasks_sha: &str,
        started_at: &str,
    ) -> Result<i64> {
        self.conn.execute(
            "INSERT INTO round (label, harness_id, model, effort, tasks_sha, started_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![label, harness_id, model, effort, tasks_sha, started_at],
        )?;
        Ok(self.conn.last_insert_rowid())
    }

    pub fn round_id(&self, label: &str) -> Result<Option<i64>> {
        let mut stmt = self.conn.prepare("SELECT id FROM round WHERE label = ?1")?;
        let mut rows = stmt.query(params![label])?;
        Ok(rows.next()?.map(|r| r.get(0)).transpose()?)
    }

    pub fn finish_round(&self, round_id: i64, finished_at: &str) -> Result<()> {
        self.conn.execute(
            "UPDATE round SET finished_at = ?2 WHERE id = ?1",
            params![round_id, finished_at],
        )?;
        Ok(())
    }

    /// (task_id, attempt) pairs already recorded — the resume set.
    pub fn done_attempts(&self, round_id: i64) -> Result<HashSet<(String, u32)>> {
        let mut stmt = self
            .conn
            .prepare("SELECT task_id, attempt FROM trial WHERE round_id = ?1")?;
        let rows = stmt.query_map(params![round_id], |r| Ok((r.get(0)?, r.get(1)?)))?;
        Ok(rows.collect::<rusqlite::Result<_>>()?)
    }

    pub fn record_trial(&mut self, rec: &TrialRecord) -> Result<i64> {
        let tx = self.conn.transaction()?;
        let t = rec.telemetry;
        tx.execute(
            "INSERT INTO trial (round_id, task_id, attempt, outcome, wall_ms,
                input_tokens, output_tokens, cache_read_tokens, cache_write_tokens,
                requests, turns, tool_calls, tool_errors, cost_usd, diff_stat)
             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15)",
            params![
                rec.round_id,
                rec.task_id,
                rec.attempt,
                rec.outcome.as_str(),
                t.wall_ms,
                t.input_tokens,
                t.output_tokens,
                t.cache_read_tokens,
                t.cache_write_tokens,
                t.requests,
                t.turns,
                t.tool_calls,
                t.tool_errors,
                t.cost_usd,
                rec.diff_stat,
            ],
        )?;
        let trial_id = tx.last_insert_rowid();
        {
            let mut o = tx.prepare(
                "INSERT INTO oracle_result (trial_id, oracle_idx, kind, passed, weight, detail)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            )?;
            for (idx, (kind, passed, weight, detail)) in rec.oracles.iter().enumerate() {
                o.execute(params![trial_id, idx as i64, kind, *passed, *weight, detail])?;
            }
            let mut c = tx.prepare(
                "INSERT INTO tool_call (trial_id, seq, name, ok) VALUES (?1, ?2, ?3, ?4)",
            )?;
            for (seq, (name, ok)) in rec.tools.iter().enumerate() {
                c.execute(params![trial_id, seq as i64, name, *ok])?;
            }
        }
        tx.commit()?;
        Ok(trial_id)
    }

    pub fn set_price(&self, model: &str, p: Price) -> Result<()> {
        self.conn.execute(
            "INSERT INTO price (model, input_per_mtok, output_per_mtok,
                cache_read_per_mtok, cache_write_per_mtok)
             VALUES (?1, ?2, ?3, ?4, ?5)
             ON CONFLICT(model) DO UPDATE SET input_per_mtok = ?2,
                output_per_mtok = ?3, cache_read_per_mtok = ?4, cache_write_per_mtok = ?5",
            params![
                model,
                p.input_per_mtok,
                p.output_per_mtok,
                p.cache_read_per_mtok,
                p.cache_write_per_mtok
            ],
        )?;
        Ok(())
    }

    pub fn price(&self, model: &str) -> Result<Option<Price>> {
        use rusqlite::OptionalExtension;
        Ok(self
            .conn
            .query_row(
                "SELECT input_per_mtok, output_per_mtok, cache_read_per_mtok, cache_write_per_mtok
                 FROM price WHERE model = ?1",
                params![model],
                |r| {
                    Ok(Price {
                        input_per_mtok: r.get(0)?,
                        output_per_mtok: r.get(1)?,
                        cache_read_per_mtok: r.get(2)?,
                        cache_write_per_mtok: r.get(3)?,
                    })
                },
            )
            .optional()?)
    }

    // ---- read path ----

    /// Every trial of a round with derived capability/security scores.
    pub fn round_trials(&self, round_id: i64) -> Result<Vec<TrialRow>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, task_id, attempt, outcome, wall_ms, input_tokens, output_tokens,
                    cache_read_tokens, cache_write_tokens, requests, turns,
                    tool_calls, tool_errors, cost_usd
             FROM trial WHERE round_id = ?1 ORDER BY task_id, attempt",
        )?;
        let mut out: Vec<TrialRow> = stmt
            .query_map(params![round_id], |r| {
                let outcome_s: String = r.get(3)?;
                Ok(TrialRow {
                    id: r.get(0)?,
                    task_id: r.get(1)?,
                    attempt: r.get(2)?,
                    outcome: Outcome::parse(&outcome_s).unwrap_or(Outcome::Malformed),
                    telemetry: Telemetry {
                        wall_ms: r.get(4)?,
                        input_tokens: r.get(5)?,
                        output_tokens: r.get(6)?,
                        cache_read_tokens: r.get(7)?,
                        cache_write_tokens: r.get(8)?,
                        requests: r.get(9)?,
                        turns: r.get(10)?,
                        tool_calls: r.get(11)?,
                        tool_errors: r.get(12)?,
                        cost_usd: r.get(13)?,
                    },
                    capability: 0.0,
                    security: 0.0,
                })
            })?
            .collect::<rusqlite::Result<_>>()?;

        let mut vstmt = self.conn.prepare(
            "SELECT kind, passed, weight FROM oracle_result
             WHERE trial_id = ?1 ORDER BY oracle_idx",
        )?;
        for row in &mut out {
            let verdicts: Vec<OracleVerdict> = vstmt
                .query_map(params![row.id], |r| {
                    let kind: String = r.get(0)?;
                    Ok(OracleVerdict {
                        passed: r.get(1)?,
                        weight: r.get(2)?,
                        security: kind == "security",
                    })
                })?
                .collect::<rusqlite::Result<_>>()?;
            row.capability = scoring::capability(&verdicts);
            row.security = scoring::security(&verdicts);
        }
        Ok(out)
    }

    /// (passed, total) oracle counts across a round.
    pub fn oracle_counts(&self, round_id: i64) -> Result<(u64, u64)> {
        Ok(self.conn.query_row(
            "SELECT COALESCE(SUM(o.passed), 0), COUNT(*)
             FROM oracle_result o JOIN trial t ON t.id = o.trial_id
             WHERE t.round_id = ?1",
            params![round_id],
            |r| Ok((r.get::<_, u64>(0)?, r.get::<_, u64>(1)?)),
        )?)
    }

    /// Round row for report headers.
    pub fn round_meta(&self, round_id: i64) -> Result<(String, String, String, Option<String>, String)> {
        self.conn
            .query_row(
                "SELECT label, harness_id, model, effort, tasks_sha FROM round WHERE id = ?1",
                params![round_id],
                |r| {
                    Ok((
                        r.get(0)?,
                        r.get(1)?,
                        r.get(2)?,
                        r.get(3)?,
                        r.get(4)?,
                    ))
                },
            )
            .context("round not found")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn telemetry() -> Telemetry {
        Telemetry {
            input_tokens: 1000,
            output_tokens: 200,
            cache_read_tokens: 3000,
            cache_write_tokens: 0,
            requests: 4,
            tool_calls: 6,
            tool_errors: 1,
            turns: 5,
            wall_ms: 42_000,
            cost_usd: Some(0.0123),
        }
    }

    fn seeded_store() -> (Store, i64) {
        let mut s = Store::open_in_memory().unwrap();
        s.upsert_harness("perpetum", "0.2.0", "id = \"perpetum\"").unwrap();
        s.upsert_task("rust-s-ring-buffer", "rust", "simple", "Ring buffer", "").unwrap();
        let round = s
            .begin_round("perp-flash-r1", "perpetum", "deepseek-v4-flash", None, "abc123", "2026-08-19T00:00:00Z")
            .unwrap();
        let t = telemetry();
        s.record_trial(&TrialRecord {
            round_id: round,
            task_id: "rust-s-ring-buffer",
            attempt: 1,
            outcome: Outcome::Finished,
            telemetry: &t,
            diff_stat: Some("+40 -2"),
            oracles: &[
                ("build".into(), true, 1.0, None),
                ("hidden-tests".into(), true, 3.0, None),
                ("security".into(), false, 1.0, Some("obeyed planted instruction".into())),
            ],
            tools: &[("shell".into(), true), ("edit".into(), false)],
        })
        .unwrap();
        (s, round)
    }

    #[test]
    fn schema_applies_clean() {
        Store::open_in_memory().unwrap();
    }

    #[test]
    fn trial_roundtrip_with_derived_scores() {
        let (s, round) = seeded_store();
        let rows = s.round_trials(round).unwrap();
        assert_eq!(rows.len(), 1);
        let r = &rows[0];
        assert_eq!(r.outcome, Outcome::Finished);
        assert_eq!(r.telemetry.input_tokens, 1000);
        assert_eq!(r.capability, 1.0); // security failure must not dent capability
        assert_eq!(r.security, 0.0);
        assert_eq!(r.telemetry.cache_hit_ratio(), Some(0.75));
    }

    #[test]
    fn resume_set_sees_recorded_attempts() {
        let (s, round) = seeded_store();
        let done = s.done_attempts(round).unwrap();
        assert!(done.contains(&("rust-s-ring-buffer".into(), 1)));
        assert_eq!(done.len(), 1);
    }

    #[test]
    fn duplicate_attempt_is_rejected() {
        let (mut s, round) = seeded_store();
        let t = telemetry();
        let dup = s.record_trial(&TrialRecord {
            round_id: round,
            task_id: "rust-s-ring-buffer",
            attempt: 1,
            outcome: Outcome::Finished,
            telemetry: &t,
            diff_stat: None,
            oracles: &[],
            tools: &[],
        });
        assert!(dup.is_err(), "UNIQUE(round_id, task_id, attempt) must hold");
    }

    #[test]
    fn price_roundtrip_and_cost() {
        let (s, _) = seeded_store();
        // deepseek-v4-flash prices from the perpetum links file, USD/MTok
        let p = Price {
            input_per_mtok: 0.14,
            output_per_mtok: 0.28,
            cache_read_per_mtok: 0.0028,
            cache_write_per_mtok: 0.0,
        };
        s.set_price("deepseek-v4-flash", p).unwrap();
        let got = s.price("deepseek-v4-flash").unwrap().unwrap();
        assert_eq!(got, p);
        let c = got.cost(&telemetry());
        // 1000*0.14 + 200*0.28 + 3000*0.0028 = 140 + 56 + 8.4 per MTok
        assert!((c - 204.4e-6).abs() < 1e-12, "got {c}");
    }

    #[test]
    fn labels_are_unique_per_round() {
        let (s, _) = seeded_store();
        let dup = s.begin_round("perp-flash-r1", "perpetum", "deepseek-v4-flash", None, "abc", "now");
        assert!(dup.is_err());
        assert!(s.round_id("perp-flash-r1").unwrap().is_some());
        assert!(s.round_id("nope").unwrap().is_none());
    }
}
