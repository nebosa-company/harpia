//! Pluggable harness adapters. A harness is declared by a TOML manifest in
//! `harnesses/<id>.toml`; adding a new harness must not require recompiling.

use harpia_core::metrics::Telemetry;
use serde::Deserialize;

/// Adapter manifest, one file per harness under `harnesses/`.
#[derive(Debug, Clone, Deserialize)]
pub struct Manifest {
    pub id: String,
    /// Command template. Placeholders: {prompt_file} {workspace} {model} {effort} {timeout_secs}
    pub command: Vec<String>,
    #[serde(default)]
    pub env: std::collections::BTreeMap<String, String>,
    /// Which built-in parser reads this harness's telemetry.
    pub telemetry: TelemetryKind,
    /// Where the telemetry lives after a run, relative to the workspace
    /// (for `stdout` kinds this is ignored).
    #[serde(default)]
    pub telemetry_path: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum TelemetryKind {
    /// Perpetum `.harness/journal.jsonl`.
    PerpetumJournal,
    /// Claude Code `--output-format stream-json` on stdout.
    ClaudeStreamJson,
    /// dsh output format.
    Dsh,
    /// Any harness that can emit `{"input_tokens":..}` JSONL lines.
    GenericJsonl,
}

pub trait Adapter {
    fn manifest(&self) -> &Manifest;
    fn parse_telemetry(&self, raw: &str) -> anyhow::Result<Telemetry>;
}
