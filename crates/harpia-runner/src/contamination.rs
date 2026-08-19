//! Were the tasks ours, and are they still ours alone?
//!
//! Two questions, one sweep:
//!
//! - **Canaries.** Every task workspace carries a string that exists nowhere
//!   else. A solution that reproduces a canary it was never shown is evidence
//!   the model has seen the task. That argument only holds if the canary is
//!   genuinely unique, so uniqueness is checked and recorded rather than
//!   assumed.
//! - **Overlap.** Each task is shingled and compared against an external
//!   corpus (a checkout of public benchmarks, say) and against the rest of
//!   Harpia. High external overlap means the task may be in training data;
//!   high internal overlap means two tasks are one task counted twice, which
//!   quietly doubles that item's weight in every mean.
//!
//! Containment, not Jaccard: a 40-line task embedded in a 4000-line public
//! file has a Jaccard score near zero and a containment score near one, and
//! it is the second number that should worry anyone.

use crate::tasks::TaskDir;
use anyhow::Result;
use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

/// Tokens per shingle. Five is long enough that ordinary phrases collide
/// rarely and short enough to survive light editing.
const SHINGLE: usize = 5;
const MAX_FILE: u64 = 1024 * 1024;

#[derive(Debug, Clone)]
pub struct Finding {
    pub task_id: String,
    pub canary: Option<String>,
    /// `None` when the task declares no canary at all.
    pub canary_unique: Option<bool>,
    /// Highest containment against anything examined, 0..1.
    pub max_similarity: f64,
    pub nearest_source: Option<String>,
    /// Which corpus the worst match came from: `internal`, or the label the
    /// caller gave the external tree.
    pub corpus_label: String,
}

/// Shingle set of one task: its prompt plus every text file in its workspace.
pub fn fingerprint(task: &TaskDir) -> BTreeSet<u64> {
    let mut text = task.spec.prompt.clone();
    text.push('\n');
    collect_text(&task.workspace_dir(), &mut text);
    shingles(&text)
}

/// Scan the corpus for canary defects and overlap.
pub fn scan(tasks: &[TaskDir], external: Option<&Path>, label: &str) -> Result<Vec<Finding>> {
    let prints: Vec<BTreeSet<u64>> = tasks.iter().map(fingerprint).collect();

    // Canary uniqueness: a canary must appear in its own task and no other.
    let mut owners: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for task in tasks {
        if let Some(canary) = &task.spec.canary {
            owners.entry(canary.clone()).or_default().push(task.spec.id.clone());
        }
    }
    let mut bodies: Vec<(String, String)> = Vec::with_capacity(tasks.len());
    for task in tasks {
        let mut text = task.spec.prompt.clone();
        collect_text(&task.workspace_dir(), &mut text);
        bodies.push((task.spec.id.clone(), text));
    }

    let external_files = match external {
        Some(dir) => external_shingles(dir)?,
        None => Vec::new(),
    };

    let mut out = Vec::with_capacity(tasks.len());
    for (i, task) in tasks.iter().enumerate() {
        let canary = task.spec.canary.clone();
        let canary_unique = canary.as_ref().map(|c| {
            let declared_once = owners.get(c).map(|v| v.len()) == Some(1);
            let appears_in: Vec<&str> = bodies
                .iter()
                .filter(|(_, body)| body.contains(c.as_str()))
                .map(|(id, _)| id.as_str())
                .collect();
            declared_once && appears_in == [task.spec.id.as_str()]
        });

        let mut worst = 0.0f64;
        let mut source: Option<String> = None;
        let mut from_label = label.to_string();

        for (j, other) in prints.iter().enumerate() {
            if i == j {
                continue;
            }
            let c = containment(&prints[i], other);
            if c > worst {
                worst = c;
                source = Some(format!("task:{}", tasks[j].spec.id));
                from_label = "internal".into();
            }
        }
        for (path, set) in &external_files {
            let c = containment(&prints[i], set);
            if c > worst {
                worst = c;
                source = Some(path.clone());
                from_label = label.to_string();
            }
        }

        out.push(Finding {
            task_id: task.spec.id.clone(),
            canary,
            canary_unique,
            max_similarity: worst,
            nearest_source: source,
            corpus_label: from_label,
        });
    }
    Ok(out)
}

/// Share of `a`'s shingles that also occur in `b`.
pub fn containment(a: &BTreeSet<u64>, b: &BTreeSet<u64>) -> f64 {
    if a.is_empty() {
        return 0.0;
    }
    a.intersection(b).count() as f64 / a.len() as f64
}

pub fn shingles(text: &str) -> BTreeSet<u64> {
    let tokens: Vec<&str> = text
        .split(|c: char| !c.is_ascii_alphanumeric())
        .filter(|t| !t.is_empty())
        .collect();
    if tokens.len() < SHINGLE {
        return BTreeSet::new();
    }
    tokens
        .windows(SHINGLE)
        .map(|w| {
            let mut h: u64 = 0xcbf29ce484222325;
            for t in w {
                for b in t.as_bytes() {
                    h ^= b.to_ascii_lowercase() as u64;
                    h = h.wrapping_mul(0x100000001b3);
                }
                h ^= 0x20;
                h = h.wrapping_mul(0x100000001b3);
            }
            h
        })
        .collect()
}

fn external_shingles(dir: &Path) -> Result<Vec<(String, BTreeSet<u64>)>> {
    let mut out = Vec::new();
    let mut stack = vec![dir.to_path_buf()];
    while let Some(d) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&d) else { continue };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                let name = entry.file_name();
                let name = name.to_string_lossy();
                if !matches!(name.as_ref(), ".git" | "node_modules" | "target") {
                    stack.push(path);
                }
                continue;
            }
            if entry.metadata().map(|m| m.len()).unwrap_or(0) > MAX_FILE {
                continue;
            }
            let Ok(text) = std::fs::read_to_string(&path) else { continue };
            let set = shingles(&text);
            if !set.is_empty() {
                let rel = path.strip_prefix(dir).unwrap_or(&path);
                out.push((rel.to_string_lossy().replace('\\', "/"), set));
            }
        }
    }
    Ok(out)
}

fn collect_text(dir: &Path, out: &mut String) {
    let mut stack: Vec<PathBuf> = vec![dir.to_path_buf()];
    while let Some(d) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&d) else { continue };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                stack.push(path);
                continue;
            }
            if entry.metadata().map(|m| m.len()).unwrap_or(0) > MAX_FILE {
                continue;
            }
            if let Ok(text) = std::fs::read_to_string(&path) {
                out.push_str(&text);
                out.push('\n');
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn containment_finds_an_embedded_task() {
        let task = shingles("implement a ring buffer with fixed capacity and overwrite on push");
        let big = shingles(
            "chapter one some unrelated prose about other matters entirely and at length \
             implement a ring buffer with fixed capacity and overwrite on push \
             followed by yet more unrelated prose to pad the document out \
             more filler text that shares nothing with the task at hand",
        );
        let c = containment(&task, &big);
        assert!(c > 0.8, "embedded task should be nearly contained, got {c}");
        // Jaccard would be tiny here, which is exactly why it is not used.
        let jaccard = task.intersection(&big).count() as f64 / task.union(&big).count() as f64;
        assert!(jaccard < 0.4, "jaccard {jaccard} hides what containment shows");
    }

    #[test]
    fn unrelated_text_scores_near_zero() {
        let a = shingles("build a token bucket rate limiter with an injectable clock");
        let b = shingles("render a markdown subset to html with fixture based tests");
        assert!(containment(&a, &b) < 0.05);
    }

    #[test]
    fn short_text_yields_no_shingles() {
        assert!(shingles("too short").is_empty());
        assert!(!shingles("one two three four five six").is_empty());
    }

    #[test]
    fn shingling_is_case_and_punctuation_insensitive() {
        let a = shingles("Implement a ring buffer, with capacity!");
        let b = shingles("implement a ring buffer with capacity");
        assert_eq!(a, b);
    }
}
