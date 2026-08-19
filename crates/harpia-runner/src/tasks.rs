//! Task corpus loading: every directory under the tasks root that holds a
//! `task.toml` is a task. Layout convention: `tasks/<stack>/<tier>/<slug>/`
//! with `workspace/`, `oracles/`, and `solution/` beside the spec.

use anyhow::{bail, Context, Result};
use harpia_core::task::Task;
use std::collections::BTreeSet;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct TaskDir {
    pub spec: Task,
    pub root: PathBuf,
}

impl TaskDir {
    pub fn workspace_dir(&self) -> PathBuf {
        self.root.join("workspace")
    }
    pub fn oracles_dir(&self) -> PathBuf {
        self.root.join("oracles")
    }
    pub fn solution_dir(&self) -> PathBuf {
        self.root.join("solution")
    }
    pub fn spec_toml(&self) -> Result<String> {
        std::fs::read_to_string(self.root.join("task.toml")).context("reading task.toml")
    }
}

pub fn load_tasks(root: &Path) -> Result<Vec<TaskDir>> {
    let mut found = Vec::new();
    walk(root, &mut found)?;
    let mut out = Vec::new();
    let mut ids = BTreeSet::new();
    for dir in found {
        let raw = std::fs::read_to_string(dir.join("task.toml"))
            .with_context(|| format!("reading {}", dir.display()))?;
        let spec: Task = toml::from_str(&raw)
            .with_context(|| format!("parsing {}/task.toml", dir.display()))?;
        if !ids.insert(spec.id.clone()) {
            bail!("duplicate task id `{}` at {}", spec.id, dir.display());
        }
        if !dir.join("workspace").is_dir() {
            bail!("task `{}` has no workspace/ directory", spec.id);
        }
        out.push(TaskDir { spec, root: dir });
    }
    out.sort_by(|a, b| a.spec.id.cmp(&b.spec.id));
    Ok(out)
}

fn walk(dir: &Path, found: &mut Vec<PathBuf>) -> Result<()> {
    if dir.join("task.toml").is_file() {
        found.push(dir.to_path_buf());
        return Ok(());
    }
    if !dir.is_dir() {
        return Ok(());
    }
    for entry in std::fs::read_dir(dir)? {
        let entry = entry?;
        if entry.file_type()?.is_dir() {
            walk(&entry.path(), found)?;
        }
    }
    Ok(())
}

pub fn copy_tree(src: &Path, dst: &Path) -> Result<()> {
    std::fs::create_dir_all(dst)?;
    for entry in std::fs::read_dir(src)? {
        let entry = entry?;
        let to = dst.join(entry.file_name());
        if entry.file_type()?.is_dir() {
            copy_tree(&entry.path(), &to)?;
        } else {
            std::fs::copy(entry.path(), &to)?;
        }
    }
    Ok(())
}
