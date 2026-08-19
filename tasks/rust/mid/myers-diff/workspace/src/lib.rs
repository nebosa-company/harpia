//! Minimal line-based diff scripts.

/// One entry of an edit script over lines.
#[derive(Debug, PartialEq, Eq, Clone)]
pub enum Edit {
    /// Line present in both inputs.
    Equal(String),
    /// Line only in the left input.
    Delete(String),
    /// Line only in the right input.
    Insert(String),
}

/// A minimal edit script turning the lines of `a` into the lines of `b`
/// (str::lines() splitting).
pub fn diff_lines(a: &str, b: &str) -> Vec<Edit> {
    let _ = (a, b);
    todo!("compute a minimal line diff")
}

/// Number of Delete + Insert entries in a minimal script for (a, b).
pub fn edit_distance(a: &str, b: &str) -> usize {
    let _ = (a, b);
    todo!("compute the minimal edit count")
}
