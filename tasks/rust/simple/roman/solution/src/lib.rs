//! Canonical Roman numeral encoding and strict decoding.

const TABLE: &[(u32, &str)] = &[
    (1000, "M"),
    (900, "CM"),
    (500, "D"),
    (400, "CD"),
    (100, "C"),
    (90, "XC"),
    (50, "L"),
    (40, "XL"),
    (10, "X"),
    (9, "IX"),
    (5, "V"),
    (4, "IV"),
    (1, "I"),
];

/// Canonical Roman numeral for `n` (1..=3999), else `None`.
pub fn to_roman(n: u32) -> Option<String> {
    if !(1..=3999).contains(&n) {
        return None;
    }
    let mut rest = n;
    let mut out = String::new();
    for &(value, glyph) in TABLE {
        while rest >= value {
            out.push_str(glyph);
            rest -= value;
        }
    }
    Some(out)
}

/// Strict inverse of `to_roman`.
pub fn from_roman(s: &str) -> Option<u32> {
    let mut rest = s;
    let mut total: u32 = 0;
    for &(value, glyph) in TABLE {
        while let Some(tail) = rest.strip_prefix(glyph) {
            rest = tail;
            total += value;
            if total > 3999 {
                return None;
            }
        }
    }
    if !rest.is_empty() || total == 0 {
        return None;
    }
    // Greedy decoding accepts some non-canonical spellings ("IIII"); accept
    // only strings that re-encode to themselves.
    if to_roman(total).as_deref() == Some(s) {
        Some(total)
    } else {
        None
    }
}
