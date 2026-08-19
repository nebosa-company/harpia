//! What the machine was, at the moment a round started.
//!
//! Every stack in the corpus is graded by running its real toolchain. When
//! that toolchain moves — a Rust release that tightens a lint, a Node bump
//! that changes `node:test` output — task difficulty moves with it, and
//! without a record the benchmark reports that as harnesses getting worse.
//! One JSON blob per round, and `harpia drift` compares it against the last
//! validation sweep.

use std::collections::BTreeMap;
use std::process::{Command, Stdio};

/// (tool, argv) pairs probed at round start. Absent tools are simply absent
/// from the result — a machine without Flutter records that fact rather than
/// an empty string that reads like a version.
const PROBES: &[(&str, &[&str])] = &[
    ("rustc", &["rustc", "--version"]),
    ("cargo", &["cargo", "--version"]),
    ("node", &["node", "--version"]),
    ("npm", &["npm", "--version"]),
    ("python", &["python", "--version"]),
    ("dart", &["dart", "--version"]),
    ("flutter", &["flutter", "--version"]),
    ("Rscript", &["Rscript", "--version"]),
    ("psql", &["psql", "--version"]),
    ("pwsh", &["pwsh", "--version"]),
    ("git", &["git", "--version"]),
];

/// Probe every known toolchain, best effort.
pub fn probe() -> BTreeMap<String, String> {
    PROBES
        .iter()
        .filter_map(|(name, argv)| version_of(argv).map(|v| (name.to_string(), v)))
        .collect()
}

/// The probe as compact JSON, ready for a `round.toolchain` column.
pub fn probe_json() -> String {
    to_json(&probe())
}

pub fn to_json(map: &BTreeMap<String, String>) -> String {
    serde_json::to_string(map).unwrap_or_else(|_| "{}".into())
}

pub fn from_json(raw: &str) -> BTreeMap<String, String> {
    serde_json::from_str(raw).unwrap_or_default()
}

/// Tools whose version differs between two probes, as (tool, before, after).
/// A tool present in one and missing from the other counts as a change: the
/// grading environment is not the same machine any more.
pub fn diff(
    before: &BTreeMap<String, String>,
    after: &BTreeMap<String, String>,
) -> Vec<(String, Option<String>, Option<String>)> {
    let mut keys: Vec<&String> = before.keys().chain(after.keys()).collect();
    keys.sort();
    keys.dedup();
    keys.into_iter()
        .filter(|k| before.get(*k) != after.get(*k))
        .map(|k| (k.clone(), before.get(k).cloned(), after.get(k).cloned()))
        .collect()
}

fn version_of(argv: &[&str]) -> Option<String> {
    let out = Command::new(argv[0])
        .args(&argv[1..])
        .stdin(Stdio::null())
        .output()
        .ok()?;
    let text = String::from_utf8_lossy(&out.stdout);
    let line = text
        .lines()
        .find(|l| !l.trim().is_empty())
        .map(str::trim)
        .filter(|l| !l.is_empty());
    match line {
        Some(l) => Some(l.chars().take(120).collect()),
        // Some tools print their version on stderr instead.
        None => {
            let err = String::from_utf8_lossy(&out.stderr);
            err.lines()
                .find(|l| !l.trim().is_empty())
                .map(|l| l.trim().chars().take(120).collect())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn json_round_trips() {
        let mut m = BTreeMap::new();
        m.insert("rustc".to_string(), "rustc 1.97.1".to_string());
        let json = to_json(&m);
        assert_eq!(from_json(&json), m);
        assert_eq!(from_json("not json"), BTreeMap::new());
    }

    #[test]
    fn diff_reports_upgrades_and_disappearances() {
        let before = from_json(r#"{"rustc":"1.97.1","flutter":"3.44.2"}"#);
        let after = from_json(r#"{"rustc":"1.98.0","node":"v24.1.0"}"#);
        let d = diff(&before, &after);
        let names: Vec<&str> = d.iter().map(|(k, _, _)| k.as_str()).collect();
        assert_eq!(names, ["flutter", "node", "rustc"]);
        let flutter = d.iter().find(|(k, _, _)| k == "flutter").unwrap();
        assert_eq!(flutter.2, None, "a tool that vanished is a change");
    }

    #[test]
    fn identical_probes_do_not_drift() {
        let m = from_json(r#"{"rustc":"1.97.1"}"#);
        assert!(diff(&m, &m).is_empty());
    }

    #[test]
    fn probe_finds_at_least_the_toolchain_running_these_tests() {
        let p = probe();
        assert!(p.contains_key("cargo"), "cargo ran this test: {p:?}");
        assert!(p["cargo"].contains("cargo"));
    }
}
