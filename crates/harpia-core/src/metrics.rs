//! Per-trial telemetry and derived metrics.

use serde::{Deserialize, Serialize};

/// Raw telemetry parsed from a harness's own output for one trial.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Telemetry {
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_read_tokens: u64,
    pub cache_write_tokens: u64,
    pub requests: u64,
    pub tool_calls: u64,
    pub tool_errors: u64,
    pub turns: u64,
    pub wall_ms: u64,
    pub cost_usd: Option<f64>,
}

impl Telemetry {
    /// Cache hit share of all prompt-side tokens, in [0, 1].
    pub fn cache_hit_ratio(&self) -> Option<f64> {
        let denom = self.input_tokens + self.cache_read_tokens;
        (denom > 0).then(|| self.cache_read_tokens as f64 / denom as f64)
    }
}

/// How a trial ended, independent of how well it scored.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Outcome {
    Finished,
    Timeout,
    CostCeiling,
    Crashed,
    Malformed,
}

impl Outcome {
    pub fn as_str(self) -> &'static str {
        match self {
            Outcome::Finished => "finished",
            Outcome::Timeout => "timeout",
            Outcome::CostCeiling => "cost-ceiling",
            Outcome::Crashed => "crashed",
            Outcome::Malformed => "malformed",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        Some(match s {
            "finished" => Outcome::Finished,
            "timeout" => Outcome::Timeout,
            "cost-ceiling" => Outcome::CostCeiling,
            "crashed" => Outcome::Crashed,
            "malformed" => Outcome::Malformed,
            _ => return None,
        })
    }
}

/// One model call, as the harness's own accounting reports it. This is the
/// grain the cross-round reports need: per-call latency, which link and role
/// served it, and what it cost. Harnesses that only report totals leave this
/// empty, which is itself a recorded fact.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ModelCall {
    /// Epoch seconds, when the harness recorded it.
    pub at: Option<i64>,
    /// Harness-internal step id, e.g. Perpetum's `c15/b1/s249`.
    pub step: Option<String>,
    /// Role the call served, e.g. `coder`, `verifier`.
    pub role: Option<String>,
    /// Link that carried it, e.g. `ds-fast`, `claude-deep`.
    pub link: Option<String>,
    /// Model as the harness names it on this call.
    pub model: Option<String>,
    pub input_tokens: u64,
    pub cache_read_tokens: u64,
    pub cache_write_tokens: u64,
    pub output_tokens: u64,
    pub latency_ms: Option<u64>,
    /// Real charge; `shadow` when the link is a subscription.
    pub cost_usd: Option<f64>,
    /// True when the cost is imputed rather than billed.
    pub cost_is_shadow: bool,
    pub ok: bool,
}

/// One tool call with enough context to say what it did and why it failed.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ToolCall {
    pub name: String,
    pub ok: bool,
    /// One-line description of what it did, where the harness reports one.
    pub about: Option<String>,
    /// Result size in bytes, where reported.
    pub bytes: Option<u64>,
    /// Decider class when the call was refused: `rule`, `model`, `person`.
    pub refusal: Option<String>,
    pub step: Option<String>,
}
