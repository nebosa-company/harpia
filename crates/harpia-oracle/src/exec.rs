// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//! Child-process execution with a hard wall-clock budget.

use anyhow::{Context, Result};
use std::io::Read;
use std::path::Path;
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

pub struct Run {
    pub ok: bool,
    pub exit_code: Option<i32>,
    pub timed_out: bool,
    /// Last chunk of interleaved stdout+stderr, capped for storage.
    pub tail: String,
}

const TAIL_CAP: usize = 4096;

/// Kill the whole process tree. A plain `Child::kill` on Windows takes down
/// only the direct child; a grandchild keeps the stdout pipe open and the
/// drain thread blocks until *it* exits — the timeout would not be a timeout.
pub fn kill_tree(child: &mut std::process::Child) {
    #[cfg(windows)]
    {
        let _ = Command::new("taskkill")
            .args(["/T", "/F", "/PID", &child.id().to_string()])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
    }
    let _ = child.kill();
    let _ = child.wait();
}

/// Run argv in `cwd`, kill on timeout, return the outcome with an output tail.
pub fn run_cmd(argv: &[String], cwd: &Path, timeout: Duration) -> Result<Run> {
    let (program, args) = argv.split_first().context("empty command")?;
    let mut child = Command::new(program)
        .args(args)
        .current_dir(cwd)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .with_context(|| format!("spawning {program}"))?;

    // Drain pipes on threads so a chatty child can't deadlock on a full pipe.
    let mut out_pipe = child.stdout.take().unwrap();
    let mut err_pipe = child.stderr.take().unwrap();
    let out_h = std::thread::spawn(move || {
        let mut buf = Vec::new();
        let _ = out_pipe.read_to_end(&mut buf);
        buf
    });
    let err_h = std::thread::spawn(move || {
        let mut buf = Vec::new();
        let _ = err_pipe.read_to_end(&mut buf);
        buf
    });

    let started = Instant::now();
    let mut timed_out = false;
    let status = loop {
        if let Some(st) = child.try_wait()? {
            break Some(st);
        }
        if started.elapsed() >= timeout {
            timed_out = true;
            kill_tree(&mut child);
            break None;
        }
        std::thread::sleep(Duration::from_millis(25));
    };

    let mut bytes = out_h.join().unwrap_or_default();
    bytes.extend(err_h.join().unwrap_or_default());
    let text = String::from_utf8_lossy(&bytes);
    let tail = if text.len() > TAIL_CAP {
        // Byte-indexed cut must land on a char boundary: test output is full
        // of ✖-style glyphs, and slicing through one panics.
        let mut cut = text.len() - TAIL_CAP;
        while !text.is_char_boundary(cut) {
            cut += 1;
        }
        format!("…{}", &text[cut..])
    } else {
        text.into_owned()
    };

    let exit_code = status.and_then(|s| s.code());
    Ok(Run {
        ok: !timed_out && exit_code == Some(0),
        exit_code,
        timed_out,
        tail: if timed_out { format!("timed out after {timeout:?}\n{tail}") } else { tail },
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(windows)]
    #[test]
    fn timeout_kills_the_child() {
        let started = Instant::now();
        let run = run_cmd(
            &["cmd".into(), "/c".into(), "ping -n 30 127.0.0.1 > NUL".into()],
            Path::new("."),
            Duration::from_millis(700),
        )
        .unwrap();
        assert!(run.timed_out);
        assert!(!run.ok);
        assert!(started.elapsed() < Duration::from_secs(10));
    }

    #[cfg(windows)]
    #[test]
    fn captures_output_tail() {
        let run = run_cmd(
            &["cmd".into(), "/c".into(), "echo hello-tail".into()],
            Path::new("."),
            Duration::from_secs(20),
        )
        .unwrap();
        assert!(run.ok);
        assert!(run.tail.contains("hello-tail"));
    }
}
