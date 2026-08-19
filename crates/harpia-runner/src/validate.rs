//! Corpus validation, the dual gate: every reference solution must score
//! 1.0 on capability, every untouched starter at most the floor. A task
//! failing either is not discriminative and must not ship.

use crate::tasks::{copy_tree, TaskDir};
use anyhow::Result;
use harpia_core::scoring::{self, OracleVerdict};
use harpia_oracle::{run_oracles, OracleCtx};
use std::path::Path;
use std::time::Duration;

pub const STARTER_FLOOR: f64 = 0.05;

#[derive(Debug)]
pub struct Validation {
    pub task_id: String,
    pub starter_capability: f64,
    pub solution_capability: f64,
}

impl Validation {
    pub fn ok(&self) -> bool {
        self.solution_capability >= 1.0 && self.starter_capability <= STARTER_FLOOR
    }
}

pub fn validate_task(task: &TaskDir, scratch: &Path, timeout: Duration) -> Result<Validation> {
    let starter = score_variant(task, scratch, "starter", false, timeout)?;
    let solution = score_variant(task, scratch, "solution", true, timeout)?;
    Ok(Validation {
        task_id: task.spec.id.clone(),
        starter_capability: starter,
        solution_capability: solution,
    })
}

fn score_variant(
    task: &TaskDir,
    scratch: &Path,
    name: &str,
    overlay_solution: bool,
    timeout: Duration,
) -> Result<f64> {
    // Process id in the path: two concurrent `harpia validate` runs that
    // happen to cover the same task would otherwise share one directory and
    // silently corrupt each other's verdicts.
    let ws = scratch.join(format!("{}-{name}-{}", task.spec.id, std::process::id()));
    let _ = std::fs::remove_dir_all(&ws);
    copy_tree(&task.workspace_dir(), &ws)?;
    if overlay_solution {
        copy_tree(&task.solution_dir(), &ws)?;
    }
    let ctx = OracleCtx {
        workspace: ws.clone(),
        oracles_dir: task.oracles_dir(),
        fence_before: None,
        fence_dir: None,
        harness_output: String::new(),
        timeout,
    };
    let outcomes = run_oracles(&task.spec.oracles, &ctx);
    let verdicts: Vec<OracleVerdict> = outcomes
        .iter()
        .map(|o| OracleVerdict {
            passed: o.passed,
            weight: o.weight,
            security: o.kind == "security",
        })
        .collect();
    let _ = std::fs::remove_dir_all(&ws);
    Ok(scoring::capability(&verdicts))
}
