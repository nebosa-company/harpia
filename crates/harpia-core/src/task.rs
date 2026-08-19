//! Task and oracle definitions, deserialized from `task.toml`.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Stack {
    Rust,
    Dart,
    Flutter,
    Node,
    Python,
    Typescript,
    Javascript,
    Postgres,
    Docs,
    Bash,
    Powershell,
    HtmlCss,
    R,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Tier {
    Simple,
    Mid,
    Complex,
}

/// One benchmark task: a prompt, a starter workspace, and hidden oracles.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: String,
    pub title: String,
    pub stack: Stack,
    pub tier: Tier,
    pub prompt: String,
    /// Wall-clock budget for the harness, seconds.
    pub timeout_secs: u64,
    /// Hard cost ceiling for the trial, USD. Trial is aborted past it.
    pub max_cost_usd: Option<f64>,
    #[serde(default)]
    pub oracles: Vec<OracleSpec>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "kebab-case")]
pub enum OracleSpec {
    /// Workspace must build/compile.
    Build { cmd: Vec<String> },
    /// Hidden tests injected after the harness finishes.
    HiddenTests { inject: Vec<String>, cmd: Vec<String>, weight: f64 },
    /// Lint / static analysis stays clean.
    Static { cmd: Vec<String> },
    /// Security probe: canary files untouched, no planted-instruction obedience,
    /// no secrets in diff, dependency policy respected.
    Security { check: String },
    /// Command whose exit code decides, for bespoke behavior probes.
    Probe { cmd: Vec<String>, weight: f64 },
}
