use nfa_regex::Regex;

fn matches(pattern: &str, text: &str) -> bool {
    Regex::compile(pattern)
        .unwrap_or_else(|e| panic!("pattern {pattern:?} failed to compile: {e:?}"))
        .is_match(text)
}

#[test]
fn literals_are_anchored() {
    assert!(matches("abc", "abc"));
    assert!(!matches("abc", "abcd"));
    assert!(!matches("abc", "zabc"));
    assert!(!matches("b", "abc"));
    assert!(!matches("abc", ""));
}

#[test]
fn dot_matches_any_single_char() {
    assert!(matches("a.c", "abc"));
    assert!(matches("a.c", "a.c"));
    assert!(matches("...", "xyz"));
    assert!(!matches("...", "xy"));
    assert!(!matches("a.c", "ac"));
}

#[test]
fn star_plus_question() {
    assert!(matches("ab*c", "ac"));
    assert!(matches("ab*c", "abc"));
    assert!(matches("ab*c", "abbbbc"));
    assert!(!matches("ab*c", "abxc"));
    assert!(!matches("ab+c", "ac"));
    assert!(matches("ab+c", "abc"));
    assert!(matches("ab+c", "abbc"));
    assert!(matches("ab?c", "ac"));
    assert!(matches("ab?c", "abc"));
    assert!(!matches("ab?c", "abbc"));
}

#[test]
fn classes_and_ranges() {
    assert!(matches("[abc]x", "bx"));
    assert!(!matches("[abc]x", "dx"));
    assert!(matches("[a-z]+", "hello"));
    assert!(!matches("[a-z]+", "hello7"));
    assert!(matches("v[0-9]+", "v42"));
    assert!(matches("[a-cA-C]", "B"));
    assert!(!matches("[a-cA-C]", "d"));
}

#[test]
fn negated_classes() {
    assert!(matches("[^0-9]+", "abc"));
    assert!(!matches("[^0-9]+", "ab3"));
    assert!(matches("[^x]", "y"));
    assert!(!matches("[^x]", "x"));
    assert!(!matches("[^x]", "yy"), "a class consumes exactly one char");
}

#[test]
fn alternation_and_groups() {
    assert!(matches("cat|dog", "cat"));
    assert!(matches("cat|dog", "dog"));
    assert!(!matches("cat|dog", "cow"));
    assert!(matches("(ab|cd)ef", "abef"));
    assert!(matches("(ab|cd)ef", "cdef"));
    assert!(!matches("(ab|cd)ef", "abcd"));
    assert!(matches("gr(a|e)y", "gray"));
    assert!(matches("gr(a|e)y", "grey"));
}

#[test]
fn quantified_groups() {
    assert!(matches("(ab)+", "ab"));
    assert!(matches("(ab)+", "ababab"));
    assert!(!matches("(ab)+", "aba"));
    assert!(matches("(a|b)*c", "c"));
    assert!(matches("(a|b)*c", "abbac"));
    assert!(matches("a(b|c)?d", "ad"));
    assert!(matches("a(b|c)?d", "acd"));
    assert!(!matches("a(b|c)?d", "abcd"));
}

#[test]
fn nested_structures() {
    assert!(matches("((a|b)c)*d", "d"));
    assert!(matches("((a|b)c)*d", "acbcd"));
    assert!(!matches("((a|b)c)*d", "abd"));
    assert!(matches("(a(b(c)?)?)?", ""));
    assert!(matches("(a(b(c)?)?)?", "ab"));
    assert!(matches("(a(b(c)?)?)?", "abc"));
    assert!(!matches("(a(b(c)?)?)?", "ac"));
}

#[test]
fn escapes_make_literals() {
    assert!(matches(r"a\.c", "a.c"));
    assert!(!matches(r"a\.c", "abc"));
    assert!(matches(r"\(1\+2\)", "(1+2)"));
    assert!(matches(r"C:\\temp", r"C:\temp"));
    assert!(matches(r"a\*b", "a*b"));
    assert!(!matches(r"a\*b", "aab"));
    assert!(matches(r"x\|y", "x|y"));
    assert!(!matches(r"x\|y", "x"));
}
