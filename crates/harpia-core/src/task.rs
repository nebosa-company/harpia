// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

/// What kind of work the task is. Reported as its own cut, because a bench
/// that only separates harnesses on greenfield building says nothing about
/// the debugging and refactoring that agentic work is mostly made of.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Family {
    Build,
    Debug,
    Refactor,
    Legacy,
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
    /// Optional; absent on tasks authored before families were recorded.
    #[serde(default)]
    pub family: Option<Family>,
    /// Same requirement, different wording. A round pinned to variant *k*
    /// measures how much of a score is the prompt's phrasing rather than the
    /// harness's competence. Empty means "verbatim only".
    #[serde(default)]
    pub prompt_variants: Vec<String>,
    /// Unique string planted in this task's workspace. A solution that
    /// reproduces a canary it was never shown is evidence of contamination,
    /// and a canary that is not unique cannot support that claim.
    #[serde(default)]
    pub canary: Option<String>,
    /// Dependencies a solution may legitimately add. Anything else appearing
    /// in a manifest is a gaming signal, not a design choice.
    #[serde(default)]
    pub allowed_dependencies: Vec<String>,
}

impl Task {
    /// The prompt a trial should use: variant `k`, or the canonical text.
    /// `None` when variant `k` was asked for and this task has no such
    /// variant — the caller records that as an unmeasured cell rather than
    /// quietly running the canonical prompt and calling it variant `k`.
    pub fn prompt_variant(&self, k: usize) -> Option<&str> {
        if k == 0 {
            return Some(&self.prompt);
        }
        self.prompt_variants.get(k - 1).map(String::as_str)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn task(variants: Vec<String>) -> Task {
        Task {
            id: "t".into(),
            title: "t".into(),
            stack: Stack::Rust,
            tier: Tier::Simple,
            prompt: "canonical".into(),
            timeout_secs: 60,
            max_cost_usd: None,
            oracles: vec![],
            family: None,
            prompt_variants: variants,
            canary: None,
            allowed_dependencies: vec![],
        }
    }

    #[test]
    fn variant_zero_is_the_canonical_prompt() {
        assert_eq!(task(vec![]).prompt_variant(0), Some("canonical"));
    }

    #[test]
    fn a_missing_variant_is_absent_not_substituted() {
        assert_eq!(task(vec![]).prompt_variant(1), None);
        let t = task(vec!["reworded".into()]);
        assert_eq!(t.prompt_variant(1), Some("reworded"));
        assert_eq!(t.prompt_variant(2), None);
    }

    #[test]
    fn legacy_task_toml_still_parses() {
        let raw = r#"
            id = "rust-s-ring-buffer"
            title = "Ring buffer"
            stack = "rust"
            tier = "simple"
            prompt = "build it"
            timeout_secs = 300
        "#;
        let t: Task = toml::from_str(raw).unwrap();
        assert!(t.prompt_variants.is_empty());
        assert!(t.family.is_none());
        assert!(t.canary.is_none());
    }
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
