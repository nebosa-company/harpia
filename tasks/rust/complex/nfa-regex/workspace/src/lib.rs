//! An anchored regex subset compiled to a Thompson NFA and simulated with
//! state sets (linear time, no backtracking).

/// Compile-time pattern errors.
#[derive(Debug, PartialEq)]
pub enum RegexError {
    /// Unclosed '(' or stray ')'.
    UnbalancedParen,
    /// Quantifier with no atom before it.
    DanglingQuantifier,
    /// Unterminated class or reversed range.
    BadClass,
    /// Backslash before an unsupported character, or trailing backslash.
    BadEscape,
}

/// A compiled pattern. `is_match` is anchored: the whole text must match.
pub struct Regex {
    _todo: std::marker::PhantomData<()>,
}

impl Regex {
    /// Compile `pattern` into an NFA.
    pub fn compile(pattern: &str) -> Result<Regex, RegexError> {
        let _ = pattern;
        todo!("parse the pattern and build the NFA")
    }

    /// Whether the ENTIRE `text` matches the pattern.
    pub fn is_match(&self, text: &str) -> bool {
        let _ = text;
        todo!("simulate the NFA over the text")
    }
}
