// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

/// Who is answerable for a trial that did not finish clean.
///
/// `Outcome` says *what* happened; this says *whose* it was. Without the
/// split, a provider 503 and a harness that cannot write a file both land as
/// `Crashed` and both read as incapability — so a bad afternoon on the
/// network becomes a permanent line on a harness's scorecard.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Fault {
    /// Trial ran as designed (whether or not the harness solved anything).
    None,
    /// The harness misbehaved: non-zero exit, unparseable output, its own bug.
    Harness,
    /// Harpia, the sandbox, the machine, or the provider let the trial down.
    Infra,
}

impl Fault {
    pub fn as_str(self) -> &'static str {
        match self {
            Fault::None => "none",
            Fault::Harness => "harness",
            Fault::Infra => "infra",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        Some(match s {
            "none" => Fault::None,
            "harness" => Fault::Harness,
            "infra" => Fault::Infra,
            _ => return None,
        })
    }
}

/// Which accounting path produced a trial's usage numbers.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum TelemetrySource {
    /// The harness's own journal / stream / log.
    FirstParty,
    /// Harpia's usage proxy, counting on the wire.
    Proxy,
    /// Both ran — the only configuration that can be cross-checked.
    Both,
    /// Neither yielded usage. Recorded, never rounded down to zero.
    Missing,
}

impl TelemetrySource {
    pub fn as_str(self) -> &'static str {
        match self {
            TelemetrySource::FirstParty => "first-party",
            TelemetrySource::Proxy => "proxy",
            TelemetrySource::Both => "both",
            TelemetrySource::Missing => "missing",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        Some(match s {
            "first-party" => TelemetrySource::FirstParty,
            "proxy" => TelemetrySource::Proxy,
            "both" => TelemetrySource::Both,
            "missing" => TelemetrySource::Missing,
            _ => return None,
        })
    }
}

/// Wire-observed usage, kept beside the harness's own numbers rather than
/// replacing them. Two independent counts that agree are the only evidence
/// either is right.
#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize)]
pub struct ProxyUsage {
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_read_tokens: u64,
    pub cache_write_tokens: u64,
    pub requests: u64,
}

impl ProxyUsage {
    pub fn total_tokens(&self) -> u64 {
        self.input_tokens + self.output_tokens + self.cache_read_tokens + self.cache_write_tokens
    }

    /// Relative disagreement with the harness's own totals, |proxy - own| /
    /// max(proxy, own). `None` when there is nothing to compare.
    pub fn disagreement(&self, own: &Telemetry) -> Option<f64> {
        let mine = self.total_tokens() as f64;
        let theirs = (own.input_tokens
            + own.output_tokens
            + own.cache_read_tokens
            + own.cache_write_tokens) as f64;
        let scale = mine.max(theirs);
        (scale > 0.0).then(|| (mine - theirs).abs() / scale)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn outcome_and_fault_round_trip() {
        for o in [
            Outcome::Finished,
            Outcome::Timeout,
            Outcome::CostCeiling,
            Outcome::Crashed,
            Outcome::Malformed,
        ] {
            assert_eq!(Outcome::parse(o.as_str()), Some(o));
        }
        for f in [Fault::None, Fault::Harness, Fault::Infra] {
            assert_eq!(Fault::parse(f.as_str()), Some(f));
        }
        for t in [
            TelemetrySource::FirstParty,
            TelemetrySource::Proxy,
            TelemetrySource::Both,
            TelemetrySource::Missing,
        ] {
            assert_eq!(TelemetrySource::parse(t.as_str()), Some(t));
        }
        assert_eq!(Fault::parse("nonsense"), None);
    }

    #[test]
    fn disagreement_is_relative_and_absent_when_silent() {
        let own = Telemetry { input_tokens: 900, output_tokens: 100, ..Default::default() };
        let proxy = ProxyUsage { input_tokens: 1000, output_tokens: 100, ..Default::default() };
        let d = proxy.disagreement(&own).unwrap();
        assert!((d - 100.0 / 1100.0).abs() < 1e-12);
        assert!(ProxyUsage::default().disagreement(&Telemetry::default()).is_none());
    }
}
