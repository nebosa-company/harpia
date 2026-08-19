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
