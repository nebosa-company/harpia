//! Pluggable harness adapters. A harness is declared by a TOML manifest in
//! `harnesses/<id>.toml`; adding a new harness must not require recompiling
//! unless it speaks a telemetry dialect no built-in parser covers.

pub mod parsers;
pub mod perpetum;

use anyhow::{bail, Context, Result};
use serde::Deserialize;
use std::collections::BTreeMap;
use std::path::Path;

/// Adapter manifest, one file per harness under `harnesses/`.
#[derive(Debug, Clone, Deserialize)]
pub struct Manifest {
    pub id: String,
    /// Command template. Placeholders: {workspace} {prompt} {prompt_file}
    /// {model} {effort} {session_id} {req_id} {timeout_secs}
    pub command: Vec<String>,
    #[serde(default)]
    pub env: BTreeMap<String, String>,
    /// Which built-in parser reads this harness's telemetry.
    pub telemetry: TelemetryKind,
    /// Where the telemetry lives after a run, relative to the workspace.
    /// Unset means stdout.
    #[serde(default)]
    pub telemetry_path: Option<String>,
    /// Extra setup the runner performs before launch.
    #[serde(default)]
    pub lifecycle: Lifecycle,
    /// Env var to point at Harpia's usage proxy for wire-captured telemetry.
    #[serde(default)]
    pub base_url_env: Option<String>,
    /// Upstream the proxy forwards to when `base_url_env` is set.
    #[serde(default)]
    pub upstream: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum TelemetryKind {
    /// Perpetum `.harness/journal.jsonl`.
    PerpetumJournal,
    /// Claude Code `--output-format stream-json` on stdout.
    ClaudeStreamJson,
    /// Harpia's own usage-proxy `requests.jsonl` (dsh and any silent harness).
    ProxyJsonl,
    /// Any harness that emits `{"input_tokens":…}` JSONL lines itself.
    GenericJsonl,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Lifecycle {
    /// Copy workspace, run command, read telemetry.
    #[default]
    Simple,
    /// `perp init` + links.md + binding patch + minted requirement first.
    Perpetum,
}

/// Values substituted into the command template for one trial.
#[derive(Debug, Clone, Default)]
pub struct TrialVars {
    pub workspace: String,
    pub prompt: String,
    pub prompt_file: String,
    pub model: String,
    pub effort: String,
    pub session_id: String,
    pub req_id: String,
    pub timeout_secs: String,
}

impl Manifest {
    pub fn load(path: &Path) -> Result<Self> {
        let raw = std::fs::read_to_string(path)
            .with_context(|| format!("reading manifest {}", path.display()))?;
        let m: Manifest = toml::from_str(&raw)
            .with_context(|| format!("parsing manifest {}", path.display()))?;
        if m.command.is_empty() {
            bail!("manifest {} has an empty command", m.id);
        }
        Ok(m)
    }

    /// Load every `*.toml` under a directory, keyed by id.
    pub fn load_dir(dir: &Path) -> Result<BTreeMap<String, Manifest>> {
        let mut out = BTreeMap::new();
        for entry in std::fs::read_dir(dir).with_context(|| format!("reading {}", dir.display()))? {
            let path = entry?.path();
            if path.extension().is_some_and(|e| e == "toml") {
                let m = Self::load(&path)?;
                if out.insert(m.id.clone(), m).is_some() {
                    bail!("duplicate harness id in {}", path.display());
                }
            }
        }
        Ok(out)
    }

    /// The concrete argv for one trial.
    pub fn argv(&self, vars: &TrialVars) -> Vec<String> {
        self.command.iter().map(|a| substitute(a, vars)).collect()
    }
}

fn substitute(template: &str, v: &TrialVars) -> String {
    template
        .replace("{workspace}", &v.workspace)
        .replace("{prompt_file}", &v.prompt_file)
        .replace("{prompt}", &v.prompt)
        .replace("{model}", &v.model)
        .replace("{effort}", &v.effort)
        .replace("{session_id}", &v.session_id)
        .replace("{req_id}", &v.req_id)
        .replace("{timeout_secs}", &v.timeout_secs)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn manifest_parses_and_substitutes() {
        let m: Manifest = toml::from_str(
            r#"
id = "demo"
command = ["tool", "--root", "{workspace}", "--brief", "{prompt}"]
telemetry = "generic-jsonl"
"#,
        )
        .unwrap();
        assert_eq!(m.lifecycle, Lifecycle::Simple);
        let argv = m.argv(&TrialVars {
            workspace: "C:/sb/t1".into(),
            prompt: "do the thing".into(),
            ..Default::default()
        });
        assert_eq!(argv, ["tool", "--root", "C:/sb/t1", "--brief", "do the thing"]);
    }

    #[test]
    fn perpetum_lifecycle_is_declarable() {
        let m: Manifest = toml::from_str(
            r#"
id = "perpetum"
lifecycle = "perpetum"
command = ["perp.exe", "run"]
telemetry = "perpetum-journal"
telemetry_path = ".harness/journal.jsonl"
"#,
        )
        .unwrap();
        assert_eq!(m.lifecycle, Lifecycle::Perpetum);
        assert_eq!(m.telemetry, TelemetryKind::PerpetumJournal);
    }
}
