//! SQLite persistence for Harpia. One file per bench database; WAL mode;
//! every write inside a transaction so a killed run never corrupts a round.

pub mod meta;

use anyhow::{Context, Result};
use harpia_core::metrics::{Fault, ModelCall, Outcome, ProxyUsage, Telemetry, TelemetrySource, ToolCall};
use harpia_core::scoring::{self, OracleVerdict};
use rusqlite::{params, Connection};
use std::collections::HashSet;
use std::path::Path;

pub const SCHEMA: &str = include_str!("schema.sql");


/// Columns added after v1. `ALTER TABLE ADD COLUMN` is the only safe
/// migration SQLite gives us, so each is attempted and a duplicate-column
/// error is the expected no-op on an already-migrated database.
const V2_COLUMNS: &[(&str, &str)] = &[
    // Identity and provenance the cross-round reports print verbatim.
    ("harness", "harness_version TEXT"),
    ("round", "link_kind TEXT"),
    ("round", "model_wire TEXT"),
    ("round", "params TEXT"),
    ("round", "thinking TEXT"),
    ("round", "jobs INTEGER"),
    ("round", "corpus_size INTEGER"),
    ("round", "harpia_version TEXT"),
    // Real clock, so elapsed and idle time are arithmetic rather than prose.
    ("round", "started_epoch INTEGER"),
    ("round", "finished_epoch INTEGER"),
    ("trial", "started_epoch INTEGER"),
    ("trial", "finished_epoch INTEGER"),
    // How the harness reached its tools, where it reports it.
    ("trial", "rung TEXT"),
    ("trial", "steps INTEGER"),
    ("trial", "stop_reason TEXT"),
    // Why a tool call failed, not just that it did.
    ("tool_call", "about TEXT"),
    ("tool_call", "bytes INTEGER"),
    ("tool_call", "refusal TEXT"),
    ("tool_call", "step TEXT"),
    // Which oracles are slow, and which cost the most points.
    ("oracle_result", "duration_ms INTEGER"),
];

/// Columns added at v3, for measuring the benchmark itself. Same ALTER-or-noop
/// discipline as v2.
const V3_COLUMNS: &[(&str, &str)] = &[
    // What the task *was*, not what the file says today. Cross-round pairing
    // reads the trial's copy: a task edited between rounds must not be
    // silently compared against its earlier self.
    ("task", "content_sha TEXT"),
    ("task", "family TEXT"),
    ("trial", "task_content_sha TEXT"),
    // Whose fault a bad trial was, and which accounting path measured it.
    ("trial", "fault TEXT"),
    ("trial", "telemetry_source TEXT"),
    ("trial", "proxy_input_tokens INTEGER"),
    ("trial", "proxy_output_tokens INTEGER"),
    ("trial", "proxy_cache_read_tokens INTEGER"),
    ("trial", "proxy_cache_write_tokens INTEGER"),
    ("trial", "proxy_requests INTEGER"),
    // Which wording the harness was given, and which process ran the trial —
    // a round assembled over three sessions can be checked for batch effects.
    ("trial", "prompt_variant INTEGER"),
    ("trial", "session_id TEXT"),
    // The knobs a sensitivity round turns. Recorded on the round so two
    // rounds that differ only in budget are comparable *as* that experiment.
    ("round", "order_seed INTEGER"),
    ("round", "budget_scale REAL"),
    ("round", "prompt_variant INTEGER"),
    ("round", "oracles_visible INTEGER"),
    ("round", "toolchain TEXT"),
    ("round", "notes TEXT"),
];

fn migrate(conn: &Connection) -> Result<()> {
    for (table, column) in V2_COLUMNS.iter().chain(V3_COLUMNS) {
        let sql = format!("ALTER TABLE {table} ADD COLUMN {column}");
        match conn.execute(&sql, []) {
            Ok(_) => {}
            // "duplicate column name" -- already migrated.
            Err(rusqlite::Error::SqliteFailure(_, Some(msg))) if msg.contains("duplicate column") => {}
            Err(e) => return Err(e).with_context(|| format!("migrating: {sql}")),
        }
    }
    Ok(())
}

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
    /// Tool calls in order, with whatever context the harness reported.
    pub tools: &'a [ToolCall],
    /// Per-call model accounting; empty when the harness reports only totals.
    pub model_calls: &'a [ModelCall],
    /// Wall-clock bounds, epoch seconds — lets a report separate elapsed
    /// round time from time the machine was actually busy.
    pub started_epoch: Option<i64>,
    pub finished_epoch: Option<i64>,
    /// How the harness reached its tools, where it says: `native` | `prompted`.
    pub rung: Option<&'a str>,
    /// Harness-internal steps executed, where it reports them.
    pub steps: Option<u64>,
    /// Why the harness stopped, in its own words.
    pub stop_reason: Option<&'a str>,
    /// Everything needed to audit the trial after the fact.
    pub provenance: TrialProvenance<'a>,
}

/// The audit trail of one trial: what it was run against, who is answerable
/// for how it ended, and where its usage numbers came from.
#[derive(Debug, Clone)]
pub struct TrialProvenance<'a> {
    pub fault: Fault,
    pub telemetry_source: TelemetrySource,
    /// Wire-observed usage, when the proxy was in the path.
    pub proxy: Option<ProxyUsage>,
    /// 0 = the canonical prompt.
    pub prompt_variant: u32,
    /// Content hash of the task *as this trial saw it*.
    pub task_content_sha: Option<&'a str>,
    /// Which `harpia run` process produced this trial.
    pub session_id: Option<&'a str>,
}

impl Default for TrialProvenance<'_> {
    fn default() -> Self {
        Self {
            fault: Fault::None,
            telemetry_source: TelemetrySource::Missing,
            proxy: None,
            prompt_variant: 0,
            task_content_sha: None,
            session_id: None,
        }
    }
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
    pub fault: Fault,
    /// What the task hashed to when this trial ran. `None` on rows written
    /// before v3 — cross-round pairing treats that as "unknown", not "same".
    pub task_content_sha: Option<String>,
}

/// Everything known about a round when it starts.
#[derive(Debug, Clone, Default)]
pub struct RoundStart<'a> {
    pub label: &'a str,
    pub harness_id: &'a str,
    pub model: &'a str,
    pub effort: Option<&'a str>,
    pub tasks_sha: &'a str,
    pub started_at: &'a str,
    /// Link kind carrying the model: `deepseek`, `claude-cli`, `lmstudio`, ...
    pub link_kind: Option<&'a str>,
    /// Model id the provider actually reported, which can differ from the
    /// configured one — an alias resolving to something else is worth seeing.
    pub model_wire: Option<&'a str>,
    /// Request parameters as JSON, verbatim.
    pub params: Option<&'a str>,
    pub thinking: Option<&'a str>,
    pub jobs: Option<u32>,
    pub corpus_size: Option<u32>,
    pub harpia_version: Option<&'a str>,
    pub started_epoch: Option<i64>,
    /// Seed that fixed the task order. Two rounds sharing it ran the corpus
    /// in the same sequence, which is what makes an order effect testable.
    pub order_seed: Option<i64>,
    /// Multiplier applied to every task's wall-clock and cost ceiling. 1.0 is
    /// the standard budget; a 2.0 round exists to measure how much of a score
    /// was the ceiling rather than the harness.
    pub budget_scale: Option<f64>,
    /// Which prompt wording the round used. 0 = canonical.
    pub prompt_variant: Option<u32>,
    /// Calibration rounds where the hidden tests were placed in the workspace
    /// before the harness ran. Never a scoring round — the gap between it and
    /// its hidden twin is the measurement.
    pub oracles_visible: Option<bool>,
    /// JSON of probed tool versions at round start.
    pub toolchain: Option<&'a str>,
    pub notes: Option<&'a str>,
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
        migrate(&conn)?;
        Ok(Self { conn })
    }

    pub fn open_in_memory() -> Result<Self> {
        let conn = Connection::open_in_memory()?;
        conn.pragma_update(None, "foreign_keys", "ON")?;
        conn.execute_batch(SCHEMA)?;
        migrate(&conn)?;
        Ok(Self { conn })
    }

    // ---- write path ----

    /// `version` is Harpia's own; `harness_version` is what the harness
    /// reports about itself (`perp 0.4.0`), which is what a report prints.
    pub fn upsert_harness(
        &self,
        id: &str,
        version: &str,
        harness_version: Option<&str>,
        manifest: &str,
    ) -> Result<()> {
        self.conn.execute(
            "INSERT INTO harness (id, version, harness_version, manifest) VALUES (?1, ?2, ?3, ?4)
             ON CONFLICT(id) DO UPDATE SET version = ?2,
                harness_version = COALESCE(?3, harness.harness_version), manifest = ?4",
            params![id, version, harness_version, manifest],
        )?;
        Ok(())
    }

    pub fn upsert_task(&self, id: &str, stack: &str, tier: &str, title: &str, spec: &str) -> Result<()> {
        self.upsert_task_full(id, stack, tier, title, spec, None, None)
    }

    /// `content_sha` covers everything a trial can see or be graded by. It is
    /// the key the comparability guard reads: two rounds may be paired on a
    /// task only if both ran the same bytes.
    #[allow(clippy::too_many_arguments)]
    pub fn upsert_task_full(
        &self,
        id: &str,
        stack: &str,
        tier: &str,
        title: &str,
        spec: &str,
        content_sha: Option<&str>,
        family: Option<&str>,
    ) -> Result<()> {
        self.conn.execute(
            "INSERT INTO task (id, stack, tier, title, spec, content_sha, family)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
             ON CONFLICT(id) DO UPDATE SET stack = ?2, tier = ?3, title = ?4, spec = ?5,
                content_sha = COALESCE(?6, task.content_sha),
                family = COALESCE(?7, task.family)",
            params![id, stack, tier, title, spec, content_sha, family],
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
        self.begin_round_full(&RoundStart {
            label,
            harness_id,
            model,
            effort,
            tasks_sha,
            started_at,
            ..Default::default()
        })
    }

    /// Full round provenance: everything a cross-round report prints in its
    /// identity block, so a reader can tell what was actually compared.
    pub fn begin_round_full(&self, r: &RoundStart) -> Result<i64> {
        self.conn.execute(
            "INSERT INTO round (label, harness_id, model, effort, tasks_sha, started_at,
                link_kind, model_wire, params, thinking, jobs, corpus_size,
                harpia_version, started_epoch, order_seed, budget_scale,
                prompt_variant, oracles_visible, toolchain, notes)
             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15,?16,?17,?18,?19,?20)",
            params![
                r.label, r.harness_id, r.model, r.effort, r.tasks_sha, r.started_at,
                r.link_kind, r.model_wire, r.params, r.thinking, r.jobs, r.corpus_size,
                r.harpia_version, r.started_epoch, r.order_seed, r.budget_scale,
                r.prompt_variant, r.oracles_visible, r.toolchain, r.notes
            ],
        )?;
        Ok(self.conn.last_insert_rowid())
    }

    pub fn round_id(&self, label: &str) -> Result<Option<i64>> {
        let mut stmt = self.conn.prepare("SELECT id FROM round WHERE label = ?1")?;
        let mut rows = stmt.query(params![label])?;
        Ok(rows.next()?.map(|r| r.get(0)).transpose()?)
    }

    pub fn finish_round(&self, round_id: i64, finished_at: &str) -> Result<()> {
        let epoch = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .ok();
        self.conn.execute(
            "UPDATE round SET finished_at = ?2, finished_epoch = ?3 WHERE id = ?1",
            params![round_id, finished_at, epoch],
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
        let p = &rec.provenance;
        let proxy = p.proxy.unwrap_or_default();
        tx.execute(
            "INSERT INTO trial (round_id, task_id, attempt, outcome, wall_ms,
                input_tokens, output_tokens, cache_read_tokens, cache_write_tokens,
                requests, turns, tool_calls, tool_errors, cost_usd, diff_stat,
                started_epoch, finished_epoch, rung, steps, stop_reason,
                fault, telemetry_source, task_content_sha, prompt_variant, session_id,
                proxy_input_tokens, proxy_output_tokens, proxy_cache_read_tokens,
                proxy_cache_write_tokens, proxy_requests)
             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15,?16,?17,?18,?19,?20,
                     ?21,?22,?23,?24,?25,?26,?27,?28,?29,?30)",
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
                rec.started_epoch,
                rec.finished_epoch,
                rec.rung,
                rec.steps,
                rec.stop_reason,
                p.fault.as_str(),
                p.telemetry_source.as_str(),
                p.task_content_sha,
                p.prompt_variant,
                p.session_id,
                proxy.input_tokens,
                proxy.output_tokens,
                proxy.cache_read_tokens,
                proxy.cache_write_tokens,
                proxy.requests,
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
                "INSERT INTO tool_call (trial_id, seq, name, ok, about, bytes, refusal, step)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            )?;
            for (seq, t) in rec.tools.iter().enumerate() {
                c.execute(params![
                    trial_id, seq as i64, t.name, t.ok, t.about, t.bytes, t.refusal, t.step
                ])?;
            }
            let mut m = tx.prepare(
                "INSERT INTO model_call (trial_id, seq, at, step, role, link, model,
                    input_tokens, cache_read_tokens, cache_write_tokens, output_tokens,
                    latency_ms, cost_usd, cost_is_shadow, ok)
                 VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15)",
            )?;
            for (seq, c) in rec.model_calls.iter().enumerate() {
                m.execute(params![
                    trial_id, seq as i64, c.at, c.step, c.role, c.link, c.model,
                    c.input_tokens, c.cache_read_tokens, c.cache_write_tokens,
                    c.output_tokens, c.latency_ms, c.cost_usd, c.cost_is_shadow, c.ok
                ])?;
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
                    tool_calls, tool_errors, cost_usd, fault, task_content_sha
             FROM trial WHERE round_id = ?1 ORDER BY task_id, attempt",
        )?;
        let mut out: Vec<TrialRow> = stmt
            .query_map(params![round_id], |r| {
                let outcome_s: String = r.get(3)?;
                let fault_s: Option<String> = r.get(14)?;
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
                    fault: fault_s
                        .as_deref()
                        .and_then(Fault::parse)
                        .unwrap_or(Fault::None),
                    task_content_sha: r.get(15)?,
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
        s.upsert_harness("perpetum", "0.1.0", Some("perp 0.4.0"), "id = \"perpetum\"").unwrap();
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
            tools: &[
                ToolCall { name: "shell".into(), ok: true, about: Some("git status".into()),
                           bytes: Some(332), ..Default::default() },
                ToolCall { name: "edit".into(), ok: false,
                           refusal: Some("rule".into()), ..Default::default() },
            ],
            model_calls: &[ModelCall {
                role: Some("coder".into()), link: Some("ds-fast".into()),
                model: Some("deepseek-v4-flash".into()), latency_ms: Some(1206),
                output_tokens: 200, cost_usd: Some(0.0123), ok: true, ..Default::default()
            }],
            started_epoch: Some(1_787_000_000),
            finished_epoch: Some(1_787_000_042),
            rung: Some("native"),
            steps: Some(3),
            stop_reason: Some("the backlog is exhausted"),
            provenance: TrialProvenance {
                fault: Fault::None,
                telemetry_source: TelemetrySource::FirstParty,
                task_content_sha: Some("task-sha-1"),
                session_id: Some("sess-test"),
                ..Default::default()
            },
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
            model_calls: &[],
            started_epoch: None,
            finished_epoch: None,
            rung: None,
            steps: None,
            stop_reason: None,
            provenance: TrialProvenance::default(),
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
