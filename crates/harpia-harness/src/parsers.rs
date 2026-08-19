//! Telemetry parsers. Each turns a harness's raw accounting into one
//! `Telemetry` plus the ordered tool-call list. A parser that finds no
//! usage at all returns `requests == 0`; the runner records that trial
//! `malformed` — missing accounting is a defect, never a silent zero.

use crate::TelemetryKind;
use harpia_core::metrics::Telemetry;
use serde_json::Value;
use std::collections::HashMap;

#[derive(Debug, Clone, Default)]
pub struct ParsedRun {
    pub telemetry: Telemetry,
    /// (tool name, ok) in call order.
    pub tools: Vec<(String, bool)>,
}

pub fn parse(kind: TelemetryKind, raw: &str) -> ParsedRun {
    match kind {
        TelemetryKind::PerpetumJournal => perpetum_journal(raw),
        TelemetryKind::ClaudeStreamJson => claude_stream_json(raw),
        TelemetryKind::ProxyJsonl | TelemetryKind::GenericJsonl => usage_jsonl(raw),
    }
}

/// Perpetum `.harness/journal.jsonl`.
/// Model calls carry `model` + `output_tokens` + `cache_hit`/`cache_miss`
/// (`cache_miss` = uncached prompt tokens) + `charge` (+`shadow` for
/// subscription links). Tool lines carry `tool` and `ok`; refusals too.
fn perpetum_journal(raw: &str) -> ParsedRun {
    let mut out = ParsedRun::default();
    let mut cost = 0.0;
    let mut any_cost = false;
    for line in raw.lines().filter(|l| !l.trim().is_empty()) {
        let Ok(v) = serde_json::from_str::<Value>(line) else { continue };
        let is_model_call = v.get("model").is_some() && v.get("output_tokens").is_some();
        if is_model_call {
            out.telemetry.requests += 1;
            out.telemetry.turns += 1;
            out.telemetry.input_tokens += u(&v, "cache_miss");
            out.telemetry.cache_read_tokens += u(&v, "cache_hit");
            out.telemetry.output_tokens += u(&v, "output_tokens");
            let charge = f(&v, "charge");
            let shadow = f(&v, "shadow");
            let c = if charge > 0.0 { charge } else { shadow };
            if v.get("charge").is_some() || v.get("shadow").is_some() {
                any_cost = true;
            }
            cost += c;
        } else if let Some(tool) = v.get("tool").and_then(Value::as_str) {
            let ok = v.get("ok").and_then(Value::as_bool).unwrap_or(false);
            out.telemetry.tool_calls += 1;
            if !ok {
                out.telemetry.tool_errors += 1;
            }
            out.tools.push((tool.to_string(), ok));
        }
    }
    if any_cost {
        out.telemetry.cost_usd = Some(cost);
    }
    out
}

/// Claude Code `--output-format stream-json`: JSONL of system/assistant/user
/// events closed by one `result` event that aggregates usage and cost.
fn claude_stream_json(raw: &str) -> ParsedRun {
    let mut out = ParsedRun::default();
    // tool_use_id -> index into out.tools, to mark errors from tool_results
    let mut by_id: HashMap<String, usize> = HashMap::new();
    for line in raw.lines().filter(|l| !l.trim().is_empty()) {
        let Ok(v) = serde_json::from_str::<Value>(line) else { continue };
        match v.get("type").and_then(Value::as_str) {
            Some("assistant") => {
                out.telemetry.requests += 1;
                for block in content_blocks(&v) {
                    if block.get("type").and_then(Value::as_str) == Some("tool_use") {
                        let name = block
                            .get("name")
                            .and_then(Value::as_str)
                            .unwrap_or("unknown")
                            .to_string();
                        out.telemetry.tool_calls += 1;
                        out.tools.push((name, true));
                        if let Some(id) = block.get("id").and_then(Value::as_str) {
                            by_id.insert(id.to_string(), out.tools.len() - 1);
                        }
                    }
                }
            }
            Some("user") => {
                for block in content_blocks(&v) {
                    if block.get("type").and_then(Value::as_str) == Some("tool_result")
                        && block.get("is_error").and_then(Value::as_bool) == Some(true)
                    {
                        out.telemetry.tool_errors += 1;
                        if let Some(idx) = block
                            .get("tool_use_id")
                            .and_then(Value::as_str)
                            .and_then(|id| by_id.get(id))
                        {
                            out.tools[*idx].1 = false;
                        }
                    }
                }
            }
            Some("result") => {
                if let Some(usage) = v.get("usage") {
                    out.telemetry.input_tokens = u(usage, "input_tokens");
                    out.telemetry.output_tokens = u(usage, "output_tokens");
                    out.telemetry.cache_read_tokens = u(usage, "cache_read_input_tokens");
                    out.telemetry.cache_write_tokens = u(usage, "cache_creation_input_tokens");
                }
                out.telemetry.turns = u(&v, "num_turns");
                if let Some(c) = v.get("total_cost_usd").and_then(Value::as_f64) {
                    out.telemetry.cost_usd = Some(c);
                }
                if out.telemetry.wall_ms == 0 {
                    out.telemetry.wall_ms = u(&v, "duration_ms");
                }
            }
            _ => {}
        }
    }
    out
}

/// One `{"input_tokens":…,"output_tokens":…,…}` object per request — the
/// format Harpia's usage proxy writes, and the format a cooperative harness
/// can emit itself.
fn usage_jsonl(raw: &str) -> ParsedRun {
    let mut out = ParsedRun::default();
    for line in raw.lines().filter(|l| !l.trim().is_empty()) {
        let Ok(v) = serde_json::from_str::<Value>(line) else { continue };
        if v.get("input_tokens").is_none() && v.get("output_tokens").is_none() {
            continue;
        }
        out.telemetry.requests += 1;
        out.telemetry.turns += 1;
        out.telemetry.input_tokens += u(&v, "input_tokens");
        out.telemetry.output_tokens += u(&v, "output_tokens");
        out.telemetry.cache_read_tokens += u(&v, "cache_read_tokens");
        out.telemetry.cache_write_tokens += u(&v, "cache_write_tokens");
    }
    out
}

fn content_blocks(event: &Value) -> impl Iterator<Item = &Value> {
    event
        .get("message")
        .and_then(|m| m.get("content"))
        .and_then(Value::as_array)
        .map(|a| a.iter())
        .into_iter()
        .flatten()
}

fn u(v: &Value, key: &str) -> u64 {
    v.get(key).and_then(Value::as_u64).unwrap_or(0)
}

fn f(v: &Value, key: &str) -> f64 {
    v.get(key).and_then(Value::as_f64).unwrap_or(0.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn perpetum_journal_real_lines() {
        // Verbatim shapes from perpetum.io's own journal.
        let raw = r#"
{"v":1,"at":1785323370,"step":"c4/chat/s61","kind":"outcome","summary":"chat call to ds-fast","ok":true,"role":"chat","link":"ds-fast","model":"deepseek-v4-flash","cache_hit":0,"cache_miss":18,"output_tokens":147,"latency_ms":1206,"charge":4.4e-05}
{"v":1,"at":1786497215,"step":"c15/b1/s249","kind":"outcome","summary":"coder call","ok":true,"role":"coder","link":"claude-deep","model":"opus","cache_hit":0,"cache_miss":2013,"output_tokens":143,"latency_ms":5925,"charge":0.0,"shadow":0.021}
{"v":1,"at":1786806975,"step":"c40/b1/s500","kind":"outcome","summary":"shell","ok":true,"tool":"shell","about":"git status","bytes":332}
{"v":1,"at":1786497229,"step":"c15/b1/s249","kind":"outcome","summary":"refused rule `shell`","requirements":["X-18"],"ok":false,"detail":"refused","refusal":"rule","subject":"shell","tool":"shell"}
{"v":1,"at":1785309526,"step":"c3/b12/s15","kind":"intent","summary":"gate: lint","requirements":["V-2"],"idempotent":true}
"#;
        let p = parse(TelemetryKind::PerpetumJournal, raw);
        assert_eq!(p.telemetry.requests, 2);
        assert_eq!(p.telemetry.input_tokens, 18 + 2013);
        assert_eq!(p.telemetry.cache_read_tokens, 0);
        assert_eq!(p.telemetry.output_tokens, 147 + 143);
        assert_eq!(p.telemetry.tool_calls, 2);
        assert_eq!(p.telemetry.tool_errors, 1);
        assert_eq!(p.tools, vec![("shell".into(), true), ("shell".into(), false)]);
        // charge where real, shadow where the link is subscription
        assert!((p.telemetry.cost_usd.unwrap() - (4.4e-05 + 0.021)).abs() < 1e-12);
    }

    #[test]
    fn claude_stream_json_counts_tools_and_reads_result() {
        let raw = r#"
{"type":"system","subtype":"init"}
{"type":"assistant","message":{"content":[{"type":"text","text":"on it"},{"type":"tool_use","id":"tu_1","name":"Bash","input":{}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"tu_1","is_error":true,"content":"boom"}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"tu_2","name":"Edit","input":{}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"tu_2","content":"ok"}]}}
{"type":"result","subtype":"success","num_turns":4,"duration_ms":61000,"total_cost_usd":0.91,"usage":{"input_tokens":1200,"cache_read_input_tokens":50000,"cache_creation_input_tokens":900,"output_tokens":3400}}
"#;
        let p = parse(TelemetryKind::ClaudeStreamJson, raw);
        assert_eq!(p.telemetry.input_tokens, 1200);
        assert_eq!(p.telemetry.cache_read_tokens, 50000);
        assert_eq!(p.telemetry.cache_write_tokens, 900);
        assert_eq!(p.telemetry.output_tokens, 3400);
        assert_eq!(p.telemetry.turns, 4);
        assert_eq!(p.telemetry.requests, 2);
        assert_eq!(p.telemetry.tool_calls, 2);
        assert_eq!(p.telemetry.tool_errors, 1);
        assert_eq!(p.tools, vec![("Bash".into(), false), ("Edit".into(), true)]);
        assert_eq!(p.telemetry.cost_usd, Some(0.91));
        assert!((p.telemetry.cache_hit_ratio().unwrap() - 50000.0 / 51200.0).abs() < 1e-9);
    }

    #[test]
    fn usage_jsonl_sums_requests() {
        let raw = r#"
{"input_tokens":100,"output_tokens":20,"cache_read_tokens":400,"status":200}
{"input_tokens":30,"output_tokens":10,"cache_read_tokens":500,"status":200}
{"note":"not a usage line"}
"#;
        let p = parse(TelemetryKind::ProxyJsonl, raw);
        assert_eq!(p.telemetry.requests, 2);
        assert_eq!(p.telemetry.input_tokens, 130);
        assert_eq!(p.telemetry.cache_read_tokens, 900);
    }

    #[test]
    fn empty_input_reads_as_no_accounting() {
        let p = parse(TelemetryKind::GenericJsonl, "");
        assert_eq!(p.telemetry.requests, 0, "runner must mark this malformed");
    }
}
