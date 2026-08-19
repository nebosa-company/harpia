//! Canonical Roman numeral encoding and strict decoding.

/// Canonical Roman numeral for `n` (1..=3999), else `None`.
pub fn to_roman(n: u32) -> Option<String> {
    let _ = n;
    todo!("encode to a canonical Roman numeral")
}

/// Strict inverse of `to_roman`: `Some(n)` only for canonical uppercase
/// numerals of 1..=3999, `None` for everything else.
pub fn from_roman(s: &str) -> Option<u32> {
    let _ = s;
    todo!("decode a canonical Roman numeral")
}
