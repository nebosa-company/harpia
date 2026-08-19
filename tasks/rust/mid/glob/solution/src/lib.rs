//! Whole-path glob matching with `*`, `?`, character classes, and
//! segment-spanning `**`.

/// One parsed token of a single-segment pattern.
enum Tok {
    Lit(char),
    AnyChar,
    Star,
    Class { negated: bool, chars: Vec<char>, ranges: Vec<(char, char)> },
}

/// Parse one segment's pattern into tokens. None = invalid pattern.
fn parse_segment(seg: &str) -> Option<Vec<Tok>> {
    let chars: Vec<char> = seg.chars().collect();
    let mut toks = Vec::new();
    let mut i = 0usize;
    while i < chars.len() {
        match chars[i] {
            '?' => {
                toks.push(Tok::AnyChar);
                i += 1;
            }
            '*' => {
                toks.push(Tok::Star);
                i += 1;
            }
            '[' => {
                i += 1;
                let negated = i < chars.len() && chars[i] == '!';
                if negated {
                    i += 1;
                }
                let mut set_chars = Vec::new();
                let mut ranges = Vec::new();
                let mut first = true;
                let mut closed = false;
                while i < chars.len() {
                    let c = chars[i];
                    if c == ']' && !first {
                        closed = true;
                        i += 1;
                        break;
                    }
                    first = false;
                    // Range? c '-' x where '-' is not last-in-class
                    if i + 2 < chars.len() && chars[i + 1] == '-' && chars[i + 2] != ']' {
                        let (lo, hi) = (c, chars[i + 2]);
                        if hi < lo {
                            return None;
                        }
                        ranges.push((lo, hi));
                        i += 3;
                    } else {
                        set_chars.push(c);
                        i += 1;
                    }
                }
                if !closed {
                    return None;
                }
                toks.push(Tok::Class { negated, chars: set_chars, ranges });
            }
            c => {
                toks.push(Tok::Lit(c));
                i += 1;
            }
        }
    }
    Some(toks)
}

fn tok_matches(tok: &Tok, c: char) -> bool {
    match tok {
        Tok::Lit(l) => *l == c,
        Tok::AnyChar => c != '/',
        Tok::Star => unreachable!("stars handled by the walker"),
        Tok::Class { negated, chars, ranges } => {
            if c == '/' {
                return false;
            }
            let inside = chars.contains(&c) || ranges.iter().any(|&(lo, hi)| lo <= c && c <= hi);
            inside != *negated
        }
    }
}

/// Match one segment's tokens against one path segment (backtracking on *).
fn segment_match(toks: &[Tok], text: &[char]) -> bool {
    match toks.first() {
        None => text.is_empty(),
        Some(Tok::Star) => {
            // Try every split point.
            for skip in 0..=text.len() {
                if segment_match(&toks[1..], &text[skip..]) {
                    return true;
                }
            }
            false
        }
        Some(tok) => match text.first() {
            Some(&c) if tok_matches(tok, c) => segment_match(&toks[1..], &text[1..]),
            _ => false,
        },
    }
}

fn walk(pat_segs: &[PatSeg], path_segs: &[&str]) -> bool {
    match pat_segs.first() {
        None => path_segs.is_empty(),
        Some(PatSeg::DoubleStar) => {
            // Zero or more whole segments.
            for skip in 0..=path_segs.len() {
                if walk(&pat_segs[1..], &path_segs[skip..]) {
                    return true;
                }
            }
            false
        }
        Some(PatSeg::Toks(toks)) => match path_segs.first() {
            Some(seg) => {
                let chars: Vec<char> = seg.chars().collect();
                segment_match(toks, &chars) && walk(&pat_segs[1..], &path_segs[1..])
            }
            None => false,
        },
    }
}

enum PatSeg {
    DoubleStar,
    Toks(Vec<Tok>),
}

/// Does `pattern` match all of `path`?
pub fn glob_match(pattern: &str, path: &str) -> bool {
    let mut pat_segs = Vec::new();
    for seg in pattern.split('/') {
        if seg == "**" {
            pat_segs.push(PatSeg::DoubleStar);
        } else {
            match parse_segment(seg) {
                Some(toks) => pat_segs.push(PatSeg::Toks(toks)),
                None => return false,
            }
        }
    }
    let path_segs: Vec<&str> = path.split('/').collect();
    walk(&pat_segs, &path_segs)
}
