//! Task content hashing — the key the comparability guard turns.
//!
//! Two rounds may be paired on a task only if both ran the same bytes. A
//! corpus SHA is too coarse for that (any edit anywhere moves it) and a task
//! id is far too loose (the same id can name two different tasks a month
//! apart). What matters is the content of *this* task, so that is what gets
//! hashed: the spec, the workspace the harness sees, and the oracles that
//! grade it.
//!
//! `solution/` is deliberately excluded. It never enters a trial sandbox, so
//! editing a reference solution cannot change what a round measured, and
//! including it would drop pairings that are perfectly valid.

use crate::tasks::TaskDir;
use anyhow::{Context, Result};
use harpia_core::hash::{hex, Sha256};
use std::path::Path;

/// Short content hash of everything a trial can see or be graded by.
pub fn content_sha(task: &TaskDir) -> Result<String> {
    let mut files: Vec<(String, Vec<u8>)> = Vec::new();
    let spec = task.root.join("task.toml");
    if spec.is_file() {
        files.push((
            "task.toml".to_string(),
            std::fs::read(&spec).with_context(|| format!("reading {}", spec.display()))?,
        ));
    }
    for (label, dir) in [("workspace", task.workspace_dir()), ("oracles", task.oracles_dir())] {
        collect(&dir, &dir, label, &mut files)?;
    }
    // Sort by path so directory-iteration order can never change the hash.
    files.sort_by(|a, b| a.0.cmp(&b.0));

    let mut h = Sha256::new();
    for (path, bytes) in &files {
        h.update(path.as_bytes());
        h.update(b"\0");
        h.update(&(bytes.len() as u64).to_be_bytes());
        h.update(bytes);
    }
    Ok(hex(&h.finish())[..16].to_string())
}

fn collect(root: &Path, dir: &Path, label: &str, out: &mut Vec<(String, Vec<u8>)>) -> Result<()> {
    if !dir.is_dir() {
        return Ok(());
    }
    for entry in std::fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        if entry.file_type()?.is_dir() {
            collect(root, &path, label, out)?;
        } else {
            let rel = path
                .strip_prefix(root)
                .unwrap_or(&path)
                .to_string_lossy()
                // Same bytes on Windows and Linux, or the guard would drop
                // every pairing across machines.
                .replace('\\', "/");
            out.push((format!("{label}/{rel}"), std::fs::read(&path)?));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use harpia_core::task::{Stack, Task, Tier};
    use std::path::PathBuf;

    fn scratch(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("harpia-content-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(d.join("workspace")).unwrap();
        std::fs::create_dir_all(d.join("oracles")).unwrap();
        std::fs::create_dir_all(d.join("solution")).unwrap();
        std::fs::write(d.join("task.toml"), "id = \"t\"\n").unwrap();
        std::fs::write(d.join("workspace/main.rs"), "fn main() {}\n").unwrap();
        std::fs::write(d.join("oracles/test.rs"), "assert!(true)\n").unwrap();
        std::fs::write(d.join("solution/main.rs"), "fn main() { real() }\n").unwrap();
        d
    }

    fn task_at(root: PathBuf) -> TaskDir {
        TaskDir {
            spec: Task {
                id: "t".into(),
                title: "t".into(),
                stack: Stack::Rust,
                tier: Tier::Simple,
                prompt: "p".into(),
                timeout_secs: 60,
                max_cost_usd: None,
                oracles: vec![],
                family: None,
                prompt_variants: vec![],
                canary: None,
                allowed_dependencies: vec![],
            },
            root,
        }
    }

    #[test]
    fn same_content_same_hash() {
        let a = task_at(scratch("a"));
        let b = task_at(scratch("b"));
        assert_eq!(content_sha(&a).unwrap(), content_sha(&b).unwrap());
        assert_eq!(content_sha(&a).unwrap().len(), 16);
    }

    #[test]
    fn workspace_spec_and_oracle_edits_all_move_it() {
        let t = task_at(scratch("edits"));
        let base = content_sha(&t).unwrap();

        std::fs::write(t.root.join("workspace/main.rs"), "fn main() { changed() }\n").unwrap();
        let after_ws = content_sha(&t).unwrap();
        assert_ne!(base, after_ws);

        std::fs::write(t.root.join("oracles/test.rs"), "assert!(false)\n").unwrap();
        let after_oracle = content_sha(&t).unwrap();
        assert_ne!(after_ws, after_oracle);

        std::fs::write(t.root.join("task.toml"), "id = \"t\"\nprompt = \"new\"\n").unwrap();
        assert_ne!(after_oracle, content_sha(&t).unwrap());
    }

    #[test]
    fn editing_the_reference_solution_does_not_move_it() {
        let t = task_at(scratch("sol"));
        let base = content_sha(&t).unwrap();
        std::fs::write(t.root.join("solution/main.rs"), "fn main() { rewritten() }\n").unwrap();
        assert_eq!(base, content_sha(&t).unwrap(), "solution/ never enters a sandbox");
    }

    #[test]
    fn a_renamed_file_is_a_different_task() {
        let t = task_at(scratch("rename"));
        let base = content_sha(&t).unwrap();
        std::fs::rename(t.root.join("workspace/main.rs"), t.root.join("workspace/app.rs")).unwrap();
        assert_ne!(base, content_sha(&t).unwrap());
    }
}
