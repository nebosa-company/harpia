//! Whole-path glob matching with `*`, `?`, character classes, and
//! segment-spanning `**`.

/// Does `pattern` match all of `path`? See the crate rules for syntax.
/// Invalid patterns (unterminated or reversed classes) match nothing.
pub fn glob_match(pattern: &str, path: &str) -> bool {
    let _ = (pattern, path);
    todo!("match the glob")
}
