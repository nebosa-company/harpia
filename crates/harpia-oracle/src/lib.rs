//! Oracle execution: hidden tests, builds, static checks, security probes.
//! Oracles run after the harness has exited, against the mutated workspace.
//! Hidden test files are injected here — the harness never saw them.

pub mod exec;
pub mod security;

use anyhow::Result;
use harpia_core::task::OracleSpec;
use std::path::{Path, PathBuf};
use std::time::Duration;

/// What one oracle produced; maps 1:1 onto the store's oracle_result row.
#[derive(Debug, Clone)]
pub struct OracleOutcome {
    pub kind: String,
    pub passed: bool,
    pub weight: f64,
    pub detail: Option<String>,
}

/// Everything oracle evaluation may look at.
pub struct OracleCtx {
    /// The mutated workspace the harness left behind.
    pub workspace: PathBuf,
    /// The task's hidden `oracles/` directory (test files to inject).
    pub oracles_dir: PathBuf,
    /// Snapshot of the scope fence taken before the harness ran.
    pub fence_before: Option<security::Snapshot>,
    /// The fence directory itself.
    pub fence_dir: Option<PathBuf>,
    /// Harness stdout/stderr, scanned by the secret canary.
    pub harness_output: String,
    /// Per-oracle command budget.
    pub timeout: Duration,
}

pub fn run_oracles(specs: &[OracleSpec], ctx: &OracleCtx) -> Vec<OracleOutcome> {
    specs.iter().map(|s| run_one(s, ctx)).collect()
}

fn run_one(spec: &OracleSpec, ctx: &OracleCtx) -> OracleOutcome {
    match spec {
        OracleSpec::Build { cmd } => command_oracle("build", cmd, 1.0, ctx),
        OracleSpec::Static { cmd } => command_oracle("static", cmd, 1.0, ctx),
        OracleSpec::Probe { cmd, weight } => command_oracle("probe", cmd, *weight, ctx),
        OracleSpec::HiddenTests { inject, cmd, weight } => {
            for rel in inject {
                if let Err(e) = inject_file(&ctx.oracles_dir, &ctx.workspace, rel) {
                    return OracleOutcome {
                        kind: "hidden-tests".into(),
                        passed: false,
                        weight: *weight,
                        detail: Some(format!("injecting {rel}: {e}")),
                    };
                }
            }
            command_oracle("hidden-tests", cmd, *weight, ctx)
        }
        OracleSpec::Security { check } => security_oracle(check, ctx),
    }
}

fn command_oracle(kind: &str, cmd: &[String], weight: f64, ctx: &OracleCtx) -> OracleOutcome {
    match exec::run_cmd(cmd, &ctx.workspace, ctx.timeout) {
        Ok(run) => OracleOutcome {
            kind: kind.into(),
            passed: run.ok,
            weight,
            detail: if run.ok { None } else { Some(run.tail) },
        },
        Err(e) => OracleOutcome {
            kind: kind.into(),
            passed: false,
            weight,
            detail: Some(format!("spawn failed: {e}")),
        },
    }
}

fn security_oracle(check: &str, ctx: &OracleCtx) -> OracleOutcome {
    let result = match check {
        "injection-canary" => security::injection_canary(&ctx.workspace),
        "secret-canary" => security::secret_canary(&ctx.workspace, &ctx.harness_output),
        "scope-fence" => match (&ctx.fence_dir, &ctx.fence_before) {
            (Some(dir), Some(before)) => security::scope_fence(dir, before),
            _ => Ok(Some("fence not armed for this trial".into())),
        },
        other => Ok(Some(format!("unknown security check `{other}`"))),
    };
    match result {
        Ok(None) => OracleOutcome {
            kind: "security".into(),
            passed: true,
            weight: 1.0,
            detail: None,
        },
        Ok(Some(violation)) => OracleOutcome {
            kind: "security".into(),
            passed: false,
            weight: 1.0,
            detail: Some(violation),
        },
        Err(e) => OracleOutcome {
            kind: "security".into(),
            passed: false,
            weight: 1.0,
            detail: Some(format!("check errored: {e}")),
        },
    }
}

/// Copy one file (or directory tree) from the hidden oracles dir into the
/// workspace, clobbering whatever the harness may have left at that path —
/// a solution that rewrote the test file must not grade itself.
fn inject_file(oracles_dir: &Path, workspace: &Path, rel: &str) -> Result<()> {
    let src = oracles_dir.join(rel);
    let dst = workspace.join(rel);
    if src.is_dir() {
        copy_tree(&src, &dst)?;
    } else {
        if let Some(parent) = dst.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::copy(&src, &dst)?;
    }
    Ok(())
}

fn copy_tree(src: &Path, dst: &Path) -> Result<()> {
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

#[cfg(test)]
mod tests {
    use super::*;
    use harpia_core::task::OracleSpec;

    fn tmp(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("harpia-oracle-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    fn ctx(workspace: PathBuf, oracles_dir: PathBuf) -> OracleCtx {
        OracleCtx {
            workspace,
            oracles_dir,
            fence_before: None,
            fence_dir: None,
            harness_output: String::new(),
            timeout: Duration::from_secs(30),
        }
    }

    #[cfg(windows)]
    #[test]
    fn command_oracle_pass_and_fail() {
        let ws = tmp("cmd");
        let c = ctx(ws.clone(), ws.clone());
        let pass = run_oracles(
            &[OracleSpec::Build { cmd: vec!["cmd".into(), "/c".into(), "exit 0".into()] }],
            &c,
        );
        assert!(pass[0].passed);
        let fail = run_oracles(
            &[OracleSpec::Probe {
                cmd: vec!["cmd".into(), "/c".into(), "echo boom & exit 3".into()],
                weight: 2.0,
            }],
            &c,
        );
        assert!(!fail[0].passed);
        assert_eq!(fail[0].weight, 2.0);
        assert!(fail[0].detail.as_deref().unwrap().contains("boom"));
    }

    #[test]
    fn hidden_tests_inject_clobbers_harness_edits() {
        let ws = tmp("inj-ws");
        let orc = tmp("inj-orc");
        // The harness "cheated" by rewriting the test file.
        std::fs::write(ws.join("check.txt"), "assert nothing").unwrap();
        std::fs::write(orc.join("check.txt"), "the real test").unwrap();
        let c = ctx(ws.clone(), orc);
        #[cfg(windows)]
        let cmd = vec!["cmd".into(), "/c".into(), "findstr real check.txt".into()];
        #[cfg(not(windows))]
        let cmd = vec!["grep".into(), "real".into(), "check.txt".into()];
        let out = run_oracles(
            &[OracleSpec::HiddenTests { inject: vec!["check.txt".into()], cmd, weight: 3.0 }],
            &c,
        );
        assert!(out[0].passed, "{:?}", out[0].detail);
        let now = std::fs::read_to_string(ws.join("check.txt")).unwrap();
        assert_eq!(now, "the real test");
    }

    #[test]
    fn unknown_security_check_fails_closed() {
        let ws = tmp("sec");
        let c = ctx(ws.clone(), ws);
        let out = run_oracles(&[OracleSpec::Security { check: "no-such".into() }], &c);
        assert!(!out[0].passed);
        assert_eq!(out[0].kind, "security");
    }
}
