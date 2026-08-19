// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
    /// A second, independent accounting path for the same trial, relative to
    /// the workspace. When both it and `telemetry_path` yield usage, the two
    /// counts can be compared — and two independent counts that agree are the
    /// only evidence either is right.
    #[serde(default)]
    pub cross_check_path: Option<String>,
    /// Parser for `cross_check_path`. Defaults to the proxy's own JSONL.
    #[serde(default)]
    pub cross_check_telemetry: Option<TelemetryKind>,
    /// Extra setup the runner performs before launch.
    #[serde(default)]
    pub lifecycle: Lifecycle,
    /// Env var to point at Harpia's usage proxy for wire-captured telemetry.
    #[serde(default)]
    pub base_url_env: Option<String>,
    /// Upstream the proxy forwards to when `base_url_env` is set.
    #[serde(default)]
    pub upstream: Option<String>,
    /// For lifecycle = "perpetum": the link written into `.harness/links.md`.
    #[serde(default)]
    pub perpetum_link: Option<perpetum::LinkConfig>,
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

    /// Environment for the child, with `${VAR}` expansion applied to the
    /// values so a manifest can point at a machine-specific location without
    /// hardcoding one.
    pub fn env_pairs(&self) -> Vec<(String, String)> {
        self.env
            .iter()
            .map(|(k, v)| (k.clone(), expand_env(v)))
            .collect()
    }
}

fn substitute(template: &str, v: &TrialVars) -> String {
    let filled = template
        .replace("{workspace}", &v.workspace)
        .replace("{prompt_file}", &v.prompt_file)
        .replace("{prompt}", &v.prompt)
        .replace("{model}", &v.model)
        .replace("{effort}", &v.effort)
        .replace("{session_id}", &v.session_id)
        .replace("{req_id}", &v.req_id)
        .replace("{timeout_secs}", &v.timeout_secs);
    expand_env(&filled)
}

/// Expand `${VAR}` and `${VAR:-default}` from the process environment.
///
/// Manifests have to name real binaries, and a real binary lives somewhere
/// different on every machine. Without this, the choice is between a manifest
/// that only works here and one that works nowhere: the shipped manifests
/// carry a working default *and* an override, so a checkout runs unmodified
/// and a different machine needs one environment variable rather than a
/// patch.
///
/// Braces are matched by depth, so a default may itself contain a variable:
/// `${HARPIA_CLAUDE_BIN:-${APPDATA}/npm/claude.exe}`. An unset variable with
/// no default expands to nothing, which fails loudly at spawn — better than
/// silently running some other binary that happens to be on PATH.
pub fn expand_env(input: &str) -> String {
    let bytes = input.as_bytes();
    let mut out = String::with_capacity(input.len());
    let mut i = 0usize;
    while i < bytes.len() {
        if bytes[i] == b'$' && i + 1 < bytes.len() && bytes[i + 1] == b'{' {
            let start = i + 2;
            let mut depth = 1usize;
            let mut j = start;
            while j < bytes.len() && depth > 0 {
                match bytes[j] {
                    b'{' => depth += 1,
                    b'}' => depth -= 1,
                    _ => {}
                }
                j += 1;
            }
            if depth != 0 {
                // Unterminated: leave the text exactly as written rather than
                // guessing where it was meant to end.
                out.push_str(&input[i..]);
                return out;
            }
            let inner = &input[start..j - 1];
            let (name, default) = match inner.find(":-") {
                Some(k) => (&inner[..k], Some(&inner[k + 2..])),
                None => (inner, None),
            };
            let value = std::env::var(name.trim())
                .ok()
                .filter(|v| !v.is_empty())
                .unwrap_or_else(|| default.map(expand_env).unwrap_or_default());
            out.push_str(&value);
            i = j;
        } else {
            out.push(input[i..].chars().next().unwrap());
            i += input[i..].chars().next().unwrap().len_utf8();
        }
    }
    out
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
    fn env_expansion_prefers_the_override_and_falls_back() {
        std::env::set_var("HARPIA_TEST_BIN", "C:/tools/thing.exe");
        assert_eq!(
            expand_env("${HARPIA_TEST_BIN:-/usr/bin/thing}"),
            "C:/tools/thing.exe"
        );
        assert_eq!(
            expand_env("${HARPIA_TEST_UNSET_BIN:-/usr/bin/thing}"),
            "/usr/bin/thing"
        );
        // A default may itself hold a variable.
        assert_eq!(
            expand_env("${HARPIA_TEST_UNSET_BIN:-${HARPIA_TEST_BIN}/sub}"),
            "C:/tools/thing.exe/sub"
        );
        std::env::remove_var("HARPIA_TEST_BIN");
    }

    #[test]
    fn env_expansion_leaves_ordinary_text_alone() {
        assert_eq!(expand_env("plain/path --flag"), "plain/path --flag");
        assert_eq!(expand_env("{workspace}/src"), "{workspace}/src");
        // Unterminated is left verbatim rather than guessed at.
        assert_eq!(expand_env("${OPEN_FOREVER"), "${OPEN_FOREVER");
        // Unset with no default expands to nothing, so the spawn fails loudly.
        assert_eq!(expand_env("${HARPIA_TEST_DEFINITELY_UNSET}"), "");
    }

    #[test]
    fn argv_expands_env_after_placeholders() {
        std::env::set_var("HARPIA_TEST_ROOT", "D:/tools");
        let m: Manifest = toml::from_str(
            r#"
id = "demo"
command = ["${HARPIA_TEST_ROOT:-/opt}/run", "--root", "{workspace}"]
telemetry = "generic-jsonl"
"#,
        )
        .unwrap();
        let argv = m.argv(&TrialVars { workspace: "C:/sb".into(), ..Default::default() });
        assert_eq!(argv, ["D:/tools/run", "--root", "C:/sb"]);
        std::env::remove_var("HARPIA_TEST_ROOT");
    }

    #[test]
    fn cross_check_path_is_optional_and_typed() {
        let m: Manifest = toml::from_str(
            r#"
id = "demo"
command = ["tool"]
telemetry = "perpetum-journal"
telemetry_path = ".harness/journal.jsonl"
cross_check_path = "../usage.jsonl"
cross_check_telemetry = "proxy-jsonl"
"#,
        )
        .unwrap();
        assert_eq!(m.cross_check_path.as_deref(), Some("../usage.jsonl"));
        assert_eq!(m.cross_check_telemetry, Some(TelemetryKind::ProxyJsonl));

        let bare: Manifest =
            toml::from_str("id = \"d\"
command = [\"t\"]
telemetry = \"generic-jsonl\"
").unwrap();
        assert!(bare.cross_check_path.is_none());
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
