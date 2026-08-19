//! Are the oracles right?
//!
//! `harpia validate` asks whether a task can be passed and failed. It does
//! not ask whether the oracle is *measuring the right thing*, and that is the
//! larger error source in any code benchmark. Two questions, both answerable
//! automatically because every task ships a reference solution:
//!
//! - **Mutation.** Break the reference solution in a small, semantic way. The
//!   oracles must notice. A surviving mutant is an oracle that accepts wrong
//!   code — every harness scoring 1.0 on that task may have written the same
//!   bug, and the benchmark would call it solved.
//! - **Metamorphic.** Rewrite the reference solution without changing what it
//!   does — a comment, a blank line, different line endings. The oracles must
//!   keep passing it. A failure is an oracle that rejects correct code, which
//!   shows up as capability the harness never lost.
//!
//! Style oracles are held to a weaker standard than behavioural ones. A
//! `static` check that objects to a stray blank line is doing its job; the
//! same objection from `hidden-tests` is a defect. The two are reported
//! apart rather than averaged into one misleading number.

use crate::tasks::{copy_tree, TaskDir};
use anyhow::Result;
use harpia_core::scoring::{self, OracleVerdict};
use harpia_oracle::{injected_paths, run_oracles, OracleCtx};
use std::path::{Path, PathBuf};
use std::time::Duration;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AuditKind {
    Mutation,
    Metamorphic,
}

impl AuditKind {
    pub fn as_str(self) -> &'static str {
        match self {
            AuditKind::Mutation => "mutation",
            AuditKind::Metamorphic => "metamorphic",
        }
    }
}

#[derive(Debug, Clone)]
pub struct AuditOutcome {
    pub task_id: String,
    pub kind: AuditKind,
    pub operator: String,
    pub target: String,
    /// What the oracles were supposed to do with this variant.
    pub expected_pass: bool,
    pub observed: f64,
    /// The oracles behaved as they must.
    pub passed: bool,
    pub detail: Option<String>,
}

pub struct AuditConfig {
    pub scratch: PathBuf,
    pub timeout: Duration,
}

/// Apply every applicable operator to a task's reference solution and run the
/// oracles against each variant.
pub fn audit_task(task: &TaskDir, cfg: &AuditConfig) -> Result<Vec<AuditOutcome>> {
    let Some(target) = pick_source_file(&task.solution_dir()) else {
        return Ok(vec![AuditOutcome {
            task_id: task.spec.id.clone(),
            kind: AuditKind::Mutation,
            operator: "none".into(),
            target: "-".into(),
            expected_pass: false,
            observed: f64::NAN,
            passed: false,
            detail: Some("no auditable source file in solution/".into()),
        }]);
    };
    let rel = target
        .strip_prefix(task.solution_dir())
        .unwrap_or(&target)
        .to_path_buf();
    let source = std::fs::read_to_string(&target)?;
    let mut out = Vec::new();

    for (name, mutated) in mutants(&source, &rel) {
        let observed = score_variant(task, cfg, &rel, &mutated, &format!("mut-{name}"))?;
        // The oracles must have caught it. Anything at all falling over is
        // detection; which kind caught it is recorded for the report.
        let caught = observed < 1.0;
        out.push(AuditOutcome {
            task_id: task.spec.id.clone(),
            kind: AuditKind::Mutation,
            operator: name.to_string(),
            target: rel.to_string_lossy().replace('\\', "/"),
            expected_pass: false,
            observed,
            passed: caught,
            detail: (!caught).then(|| "mutant survived: the oracles accept broken code".into()),
        });
    }

    for (name, rewritten) in invariants(&source, &rel) {
        let observed = score_variant(task, cfg, &rel, &rewritten, &format!("meta-{name}"))?;
        let held = observed >= 1.0;
        out.push(AuditOutcome {
            task_id: task.spec.id.clone(),
            kind: AuditKind::Metamorphic,
            operator: name.to_string(),
            target: rel.to_string_lossy().replace('\\', "/"),
            expected_pass: true,
            observed,
            passed: held,
            detail: (!held)
                .then(|| "oracles rejected an unchanged-behaviour rewrite".to_string()),
        });
    }
    Ok(out)
}

/// Audit a whole corpus with a worker pool. Results stream back as they
/// finish; a task that errors is reported and skipped rather than taking the
/// sweep down with it.
pub fn audit_corpus(
    tasks: &[TaskDir],
    cfg: &AuditConfig,
    jobs: usize,
) -> Vec<AuditOutcome> {
    use std::sync::mpsc;
    use std::sync::{Arc, Mutex};

    let queue = Arc::new(Mutex::new((0..tasks.len()).collect::<Vec<_>>()));
    let (tx, rx) = mpsc::channel::<Vec<AuditOutcome>>();
    let mut all = Vec::new();
    std::thread::scope(|scope| {
        for _ in 0..jobs.max(1) {
            let queue = Arc::clone(&queue);
            let tx = tx.clone();
            scope.spawn(move || loop {
                let next = queue.lock().unwrap().pop();
                let Some(i) = next else { break };
                let task = &tasks[i];
                match audit_task(task, cfg) {
                    Ok(rows) => {
                        let caught = rows
                            .iter()
                            .filter(|r| r.kind == AuditKind::Mutation && r.passed)
                            .count();
                        let mutants = rows.iter().filter(|r| r.kind == AuditKind::Mutation).count();
                        eprintln!(
                            "  {:<30} {caught}/{mutants} mutants caught, {} invariants held",
                            task.spec.id,
                            rows.iter()
                                .filter(|r| r.kind == AuditKind::Metamorphic && r.passed)
                                .count()
                        );
                        let _ = tx.send(rows);
                    }
                    Err(e) => eprintln!("  {:<30} AUDIT ERROR: {e:#}", task.spec.id),
                }
            });
        }
        drop(tx);
        for rows in rx {
            all.extend(rows);
        }
    });
    all.sort_by(|a, b| {
        a.task_id
            .cmp(&b.task_id)
            .then(a.kind.as_str().cmp(b.kind.as_str()))
            .then(a.operator.cmp(&b.operator))
    });
    all
}

/// Score one rewritten solution: starter workspace, solution overlaid, the
/// target file replaced by `body`.
fn score_variant(
    task: &TaskDir,
    cfg: &AuditConfig,
    rel: &Path,
    body: &str,
    tag: &str,
) -> Result<f64> {
    let ws = cfg
        .scratch
        .join(format!("{}-{tag}-{}", task.spec.id, std::process::id()));
    let _ = std::fs::remove_dir_all(&ws);
    copy_tree(&task.workspace_dir(), &ws)?;
    copy_tree(&task.solution_dir(), &ws)?;
    let path = ws.join(rel);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(&path, body)?;

    let ctx = OracleCtx {
        workspace: ws.clone(),
        oracles_dir: task.oracles_dir(),
        timeout: cfg.timeout,
        injected_paths: injected_paths(&task.spec.oracles),
        ..Default::default()
    };
    let outcomes = run_oracles(&task.spec.oracles, &ctx);
    // Style oracles are excluded from the audit verdict: a lint that objects
    // to a blank line is doing its job, and counting that as an oracle defect
    // would bury the behavioural failures that matter.
    let verdicts: Vec<OracleVerdict> = outcomes
        .iter()
        .filter(|o| o.kind != "static")
        .map(|o| OracleVerdict {
            passed: o.passed,
            weight: o.weight,
            security: o.kind == "security",
        })
        .collect();
    let _ = std::fs::remove_dir_all(&ws);
    if verdicts.iter().all(|v| v.security) {
        // Nothing behavioural to judge — treat as unmeasured rather than 0.
        return Ok(f64::NAN);
    }
    Ok(scoring::capability(&verdicts))
}

// ---------------------------------------------------------------------------
// Operators. Pure string transforms so every one of them is unit-testable
// without a toolchain, a sandbox, or a network.
// ---------------------------------------------------------------------------

/// Semantics-*breaking* rewrites. Each returns at most one variant, applied
/// at the first site that matches, so the audit is deterministic.
pub fn mutants(source: &str, path: &Path) -> Vec<(&'static str, String)> {
    let mut out = Vec::new();
    let lang = Lang::of(path);
    for (name, from, to) in [
        ("flip-le", "<=", "<"),
        ("flip-ge", ">=", ">"),
        ("flip-eq", "==", "!="),
        ("swap-and-or", "&&", "||"),
    ] {
        if let Some(m) = replace_first_code(source, from, to, lang) {
            out.push((name, m));
        }
    }
    if let Some(m) = bump_first_int(source, lang) {
        out.push(("off-by-one", m));
    }
    if let Some(m) = flip_first_bool(source, lang) {
        out.push(("negate-bool", m));
    }
    if let Some(m) = drop_first_statement(source, lang) {
        out.push(("drop-statement", m));
    }
    out
}

/// Semantics-*preserving* rewrites: the oracles must still pass all of them.
pub fn invariants(source: &str, path: &Path) -> Vec<(&'static str, String)> {
    let lang = Lang::of(path);
    let mut out = Vec::new();
    if let Some(c) = lang.line_comment() {
        out.push((
            "trailing-comment",
            format!("{}\n{c} harpia metamorphic audit: behaviour unchanged\n", source.trim_end()),
        ));
    }
    out.push(("blank-lines", source.replace('\n', "\n\n")));
    // CRLF is a real-world difference that must not change a verdict — except
    // for scripts, where the interpreter genuinely cares about the newline.
    if !lang.newline_sensitive() && !source.starts_with("#!") {
        out.push(("crlf", source.replace("\r\n", "\n").replace('\n', "\r\n")));
    }
    out
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Lang {
    CLike,
    Hash,
    Sql,
    Other,
}

impl Lang {
    pub fn of(path: &Path) -> Self {
        match path
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("")
            .to_lowercase()
            .as_str()
        {
            "rs" | "js" | "ts" | "tsx" | "jsx" | "dart" | "go" | "java" | "c" | "h" | "cpp"
            | "cs" | "kt" | "swift" | "scala" | "css" => Lang::CLike,
            "py" | "sh" | "bash" | "r" | "rb" | "yaml" | "yml" | "toml" | "ps1" => Lang::Hash,
            "sql" => Lang::Sql,
            _ => Lang::Other,
        }
    }

    pub fn line_comment(self) -> Option<&'static str> {
        match self {
            Lang::CLike => Some("//"),
            Lang::Hash => Some("#"),
            Lang::Sql => Some("--"),
            Lang::Other => None,
        }
    }

    /// Languages whose block structure is line- or indentation-bound, where a
    /// dropped or re-terminated line is a syntax error rather than a mutant.
    pub fn newline_sensitive(self) -> bool {
        matches!(self, Lang::Hash)
    }

    fn statement_end(self) -> Option<char> {
        match self {
            Lang::CLike | Lang::Sql => Some(';'),
            _ => None,
        }
    }
}

/// Replace the first occurrence of `from` outside comments and string
/// literals. Mutating a comment produces a variant that behaves identically,
/// which would be scored as a surviving mutant and slander the oracle.
fn replace_first_code(source: &str, from: &str, to: &str, lang: Lang) -> Option<String> {
    let comment = lang.line_comment();
    let mut offset = 0usize;
    for line in source.split_inclusive('\n') {
        let code = match comment.and_then(|c| line.find(c)) {
            Some(i) => &line[..i],
            None => line,
        };
        if let Some(i) = find_outside_strings(code, from) {
            let at = offset + i;
            let mut out = String::with_capacity(source.len());
            out.push_str(&source[..at]);
            out.push_str(to);
            out.push_str(&source[at + from.len()..]);
            return Some(out);
        }
        offset += line.len();
    }
    None
}

fn find_outside_strings(code: &str, needle: &str) -> Option<usize> {
    let bytes = code.as_bytes();
    let mut quote: Option<u8> = None;
    let mut i = 0usize;
    while i < bytes.len() {
        let b = bytes[i];
        match quote {
            Some(q) => {
                if b == b'\\' {
                    i += 2;
                    continue;
                }
                if b == q {
                    quote = None;
                }
            }
            None => {
                if b == b'"' || b == b'\'' {
                    quote = Some(b);
                } else if code[i..].starts_with(needle) {
                    return Some(i);
                }
            }
        }
        i += 1;
    }
    None
}

/// First integer literal of 2 or more, incremented. Zero and one are skipped:
/// they are usually structural (`0`-index, `1`-step) and mutating them tends
/// to produce a crash rather than a wrong answer.
fn bump_first_int(source: &str, lang: Lang) -> Option<String> {
    let comment = lang.line_comment();
    let mut offset = 0usize;
    for line in source.split_inclusive('\n') {
        let code = match comment.and_then(|c| line.find(c)) {
            Some(i) => &line[..i],
            None => line,
        };
        let bytes = code.as_bytes();
        let mut i = 0usize;
        while i < bytes.len() {
            if bytes[i].is_ascii_digit() {
                let start = i;
                while i < bytes.len() && bytes[i].is_ascii_digit() {
                    i += 1;
                }
                let is_word = start > 0
                    && (bytes[start - 1].is_ascii_alphanumeric() || bytes[start - 1] == b'_');
                // Either side of a decimal point: `2.5` must not become
                // `3.5` or `2.6`. Bumping a fraction is not an off-by-one.
                let is_float =
                    (i < bytes.len() && bytes[i] == b'.') || (start > 0 && bytes[start - 1] == b'.');
                let text = &code[start..i];
                if let Ok(v) = text.parse::<u64>() {
                    if v >= 2 && !is_word && !is_float {
                        let at = offset + start;
                        let mut out = String::with_capacity(source.len() + 1);
                        out.push_str(&source[..at]);
                        out.push_str(&(v + 1).to_string());
                        out.push_str(&source[at + text.len()..]);
                        return Some(out);
                    }
                }
                continue;
            }
            i += 1;
        }
        offset += line.len();
    }
    None
}

fn flip_first_bool(source: &str, lang: Lang) -> Option<String> {
    replace_first_code(source, "true", "false", lang)
        .or_else(|| replace_first_code(source, "True", "False", lang))
}

/// Delete the first standalone statement inside a block. Only braces-and-
/// semicolons languages: in an indentation-scoped language, deleting the one
/// statement in a block is a syntax error, and a syntax error is not a mutant.
fn drop_first_statement(source: &str, lang: Lang) -> Option<String> {
    let end = lang.statement_end()?;
    let lines: Vec<&str> = source.split_inclusive('\n').collect();
    for (idx, line) in lines.iter().enumerate() {
        let t = line.trim();
        let indented = line.starts_with(' ') || line.starts_with('\t');
        let declares = t.starts_with("use ")
            || t.starts_with("import ")
            || t.starts_with("let ")
            || t.starts_with("const ")
            || t.starts_with("var ")
            || t.starts_with("return");
        if indented && t.ends_with(end) && !declares && t.len() > 4 {
            let mut out = String::with_capacity(source.len());
            for (j, l) in lines.iter().enumerate() {
                if j != idx {
                    out.push_str(l);
                }
            }
            return Some(out);
        }
    }
    None
}

/// The largest code file in the reference solution — the one most likely to
/// hold the behaviour the hidden tests exercise.
pub fn pick_source_file(solution: &Path) -> Option<PathBuf> {
    let mut best: Option<(u64, PathBuf)> = None;
    let mut stack = vec![solution.to_path_buf()];
    while let Some(dir) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&dir) else { continue };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                stack.push(path);
                continue;
            }
            if Lang::of(&path) == Lang::Other {
                continue;
            }
            let size = entry.metadata().map(|m| m.len()).unwrap_or(0);
            // Ties break on path so two equal-size files pick the same one
            // on every machine.
            let better = match &best {
                None => true,
                Some((bs, bp)) => size > *bs || (size == *bs && path < *bp),
            };
            if better {
                best = Some((size, path));
            }
        }
    }
    best.map(|(_, p)| p)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rs(name: &str) -> PathBuf {
        PathBuf::from(name)
    }

    #[test]
    fn comparison_flip_skips_comments_and_strings() {
        let src = "// keep a <= b\nlet msg = \"a <= b\";\nif x <= y { go() }\n";
        let m = replace_first_code(src, "<=", "<", Lang::CLike).unwrap();
        assert!(m.contains("// keep a <= b"), "comment must be untouched:\n{m}");
        assert!(m.contains("\"a <= b\""), "string must be untouched:\n{m}");
        assert!(m.contains("if x < y"), "code must be mutated:\n{m}");
    }

    #[test]
    fn off_by_one_bumps_a_real_literal_only() {
        assert_eq!(
            bump_first_int("let cap = 16;\n", Lang::CLike).unwrap(),
            "let cap = 17;\n"
        );
        // 0 and 1 are structural; identifiers with digits are not literals.
        assert!(bump_first_int("let i = 0; let j = 1; let u8x = 1;\n", Lang::CLike).is_none());
        // A float is left alone: 1.5 -> 2.5 is not an off-by-one.
        assert!(bump_first_int("let ratio = 2.5;\n", Lang::CLike).is_none());
        assert!(bump_first_int("# cap = 16\n", Lang::Hash).is_none(), "comment only");
    }

    #[test]
    fn statement_drop_needs_a_block_and_skips_declarations() {
        let src = "fn f() {\n    let x = 1;\n    push(x);\n    return x;\n}\n";
        let m = drop_first_statement(src, Lang::CLike).unwrap();
        assert!(!m.contains("push(x);"), "{m}");
        assert!(m.contains("let x = 1;") && m.contains("return x;"), "{m}");
        // Python: no statement terminator, so this operator does not apply.
        assert!(drop_first_statement("def f():\n    return 1\n", Lang::Hash).is_none());
    }

    #[test]
    fn every_mutant_actually_differs_from_the_source() {
        let src = "fn f(a: u32, b: u32) -> bool {\n    let n = 12;\n    if a <= b && a == n {\n        emit(a);\n        return true;\n    }\n    false\n}\n";
        let ms = mutants(src, &rs("lib.rs"));
        assert!(ms.len() >= 5, "operators applied: {:?}", ms.iter().map(|m| m.0).collect::<Vec<_>>());
        for (name, body) in &ms {
            assert_ne!(body, src, "operator {name} produced an identical file");
        }
    }

    #[test]
    fn invariants_preserve_every_original_line() {
        let src = "fn f() -> u32 {\n    7\n}\n";
        let inv = invariants(src, &rs("lib.rs"));
        let names: Vec<&str> = inv.iter().map(|(n, _)| *n).collect();
        assert!(names.contains(&"trailing-comment"));
        assert!(names.contains(&"blank-lines"));
        assert!(names.contains(&"crlf"));
        for (name, body) in &inv {
            for line in src.lines().filter(|l| !l.trim().is_empty()) {
                assert!(
                    body.replace("\r\n", "\n").contains(line),
                    "{name} dropped `{line}`"
                );
            }
        }
    }

    #[test]
    fn shell_scripts_keep_their_line_endings() {
        let names: Vec<&str> = invariants("#!/bin/sh\necho hi\n", &rs("run.sh"))
            .iter()
            .map(|(n, _)| *n)
            .collect();
        assert!(!names.contains(&"crlf"), "CRLF would break the interpreter");
    }

    #[test]
    fn language_detection_picks_comment_syntax() {
        assert_eq!(Lang::of(&rs("a.rs")).line_comment(), Some("//"));
        assert_eq!(Lang::of(&rs("a.py")).line_comment(), Some("#"));
        assert_eq!(Lang::of(&rs("a.sql")).line_comment(), Some("--"));
        assert_eq!(Lang::of(&rs("a.bin")).line_comment(), None);
    }

    #[test]
    fn source_picker_takes_the_biggest_code_file() {
        let d = std::env::temp_dir().join(format!("harpia-audit-pick-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        std::fs::create_dir_all(d.join("src")).unwrap();
        std::fs::write(d.join("README.md"), "x".repeat(5000)).unwrap();
        std::fs::write(d.join("src/small.rs"), "fn a() {}").unwrap();
        std::fs::write(d.join("src/big.rs"), "fn b() {}\n".repeat(50)).unwrap();
        let picked = pick_source_file(&d).unwrap();
        assert!(picked.ends_with("big.rs"), "{picked:?}");
        let _ = std::fs::remove_dir_all(&d);
    }
}
