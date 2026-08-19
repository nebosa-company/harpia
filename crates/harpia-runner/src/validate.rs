// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//! Corpus validation, the dual gate: every reference solution must score
//! 1.0 on capability, every untouched starter at most the floor. A task
//! failing either is not discriminative and must not ship.

use crate::content;
use crate::tasks::{copy_tree, TaskDir};
use anyhow::Result;
use harpia_core::scoring::{self, OracleVerdict};
use harpia_oracle::{injected_paths, run_oracles, OracleCtx};
use std::path::Path;
use std::time::Duration;

pub const STARTER_FLOOR: f64 = 0.05;

#[derive(Debug, Clone)]
pub struct Validation {
    pub task_id: String,
    pub starter_capability: f64,
    pub solution_capability: f64,
    /// Task content when validated, so a drift report can tell "the task
    /// changed" apart from "the toolchain moved underneath it".
    pub content_sha: Option<String>,
}

impl Validation {
    pub fn ok(&self) -> bool {
        self.solution_capability >= 1.0 && self.starter_capability <= STARTER_FLOOR
    }

    /// How much room is left before the starter stops failing. A task at
    /// 0.049 passes the gate and is one flaky assertion from being
    /// non-discriminative, which is worth seeing before it happens.
    pub fn starter_margin(&self) -> f64 {
        STARTER_FLOOR - self.starter_capability
    }

    /// Distance from the perfect score a reference solution must reach.
    pub fn solution_margin(&self) -> f64 {
        self.solution_capability - 1.0
    }

    /// Passing, but with less than a third of the floor to spare.
    pub fn marginal(&self) -> bool {
        self.ok() && self.starter_margin() < STARTER_FLOOR / 3.0
    }
}

pub fn validate_task(task: &TaskDir, scratch: &Path, timeout: Duration) -> Result<Validation> {
    let starter = score_variant(task, scratch, "starter", false, timeout)?;
    let solution = score_variant(task, scratch, "solution", true, timeout)?;
    Ok(Validation {
        task_id: task.spec.id.clone(),
        starter_capability: starter,
        solution_capability: solution,
        content_sha: content::content_sha(task).ok(),
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
        timeout,
        injected_paths: injected_paths(&task.spec.oracles),
        allowed_dependencies: task.spec.allowed_dependencies.clone(),
        ..Default::default()
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

#[cfg(test)]
mod tests {
    use super::*;

    fn v(starter: f64, solution: f64) -> Validation {
        Validation {
            task_id: "t".into(),
            starter_capability: starter,
            solution_capability: solution,
            content_sha: None,
        }
    }

    #[test]
    fn the_gate_needs_both_ends() {
        assert!(v(0.0, 1.0).ok());
        assert!(!v(0.5, 1.0).ok(), "a starter that half-passes is not discriminative");
        assert!(!v(0.0, 0.9).ok(), "a reference solution must score perfectly");
    }

    #[test]
    fn margins_expose_a_task_about_to_stop_working() {
        let comfortable = v(0.0, 1.0);
        assert!((comfortable.starter_margin() - STARTER_FLOOR).abs() < 1e-12);
        assert!(!comfortable.marginal());

        let squeaking_through = v(0.049, 1.0);
        assert!(squeaking_through.ok());
        assert!(squeaking_through.marginal(), "0.049 against a 0.05 floor is not comfortable");
        assert!(squeaking_through.starter_margin() < 0.002);
    }
}
