use nfa_regex::{Regex, RegexError};
use std::time::Instant;

fn err(pattern: &str) -> RegexError {
    match Regex::compile(pattern) {
        Err(e) => e,
        Ok(_) => panic!("pattern {pattern:?} unexpectedly compiled"),
    }
}

fn matches(pattern: &str, text: &str) -> bool {
    Regex::compile(pattern).unwrap().is_match(text)
}

#[test]
fn compile_errors() {
    assert_eq!(err("("), RegexError::UnbalancedParen);
    assert_eq!(err("(ab"), RegexError::UnbalancedParen);
    assert_eq!(err("ab)"), RegexError::UnbalancedParen);
    assert_eq!(err("a(b(c)"), RegexError::UnbalancedParen);
    assert_eq!(err("*a"), RegexError::DanglingQuantifier);
    assert_eq!(err("+a"), RegexError::DanglingQuantifier);
    assert_eq!(err("?"), RegexError::DanglingQuantifier);
    assert_eq!(err("a**"), RegexError::DanglingQuantifier);
    assert_eq!(err("a*+"), RegexError::DanglingQuantifier);
    assert_eq!(err("(*)"), RegexError::DanglingQuantifier);
    assert_eq!(err("a|*b"), RegexError::DanglingQuantifier);
    assert_eq!(err("[abc"), RegexError::BadClass);
    assert_eq!(err("[z-a]"), RegexError::BadClass);
    assert_eq!(err("[]"), RegexError::BadClass);
    assert_eq!(err(r"\q"), RegexError::BadEscape);
    assert_eq!(err("\\"), RegexError::BadEscape);
}

#[test]
fn empty_pattern_and_branches() {
    assert!(matches("", ""));
    assert!(!matches("", "a"));
    assert!(matches("a|", "a"));
    assert!(matches("a|", ""));
    assert!(!matches("a|", "b"));
    assert!(matches("(|b)a", "a"));
    assert!(matches("(|b)a", "ba"));
    assert!(matches("()", ""));
    assert!(matches("()*", ""));
}

#[test]
fn class_literal_edges() {
    assert!(matches("[]a]", "]"));
    assert!(matches("[]a]", "a"));
    assert!(!matches("[]a]", "b"));
    assert!(matches("[a-]", "-"));
    assert!(matches("[a-]", "a"));
    assert!(matches("[-a]", "-"));
    assert!(matches("x]y", "x]y"), "] outside a class is a literal");
    assert!(matches("[^]x]", "z"));
    assert!(!matches("[^]x]", "]"));
    assert!(!matches("[^]x]", "x"));
}

#[test]
fn unicode_text_and_patterns() {
    assert!(matches("héllo", "héllo"));
    assert!(matches(".+", "héllo"));
    assert!(matches("[à-ü]+", "éòù"));
    assert!(!matches("h.llo", "hllo"));
}

#[test]
fn pathological_patterns_finish_fast() {
    let start = Instant::now();

    let n = 28;
    let text: String = "a".repeat(n);
    let re = Regex::compile("(a|a)*x").unwrap();
    assert!(!re.is_match(&text), "no trailing x, must not match");

    let re = Regex::compile("(a*)*x").unwrap();
    assert!(!re.is_match(&"a".repeat(64)), "nested stars over a long run");

    // (a?)^25 a^25 against a^25: trivial for an NFA, exponential for greedy
    // backtracking.
    let pattern = "a?".repeat(25) + &"a".repeat(25);
    let re = Regex::compile(&pattern).unwrap();
    assert!(re.is_match(&"a".repeat(25)));

    let elapsed = start.elapsed();
    assert!(
        elapsed.as_secs() < 5,
        "pathological cases took {elapsed:?}; backtracking suspected"
    );
}

#[test]
fn long_linear_scan() {
    let text: String = "ab".repeat(5000);
    assert!(matches("(ab)*", &text));
    assert!(!matches("(ab)*", &(text + "a")));
    let digits = "7".repeat(10_000);
    assert!(matches("[0-9]+", &digits));
}

#[test]
fn whole_match_composition() {
    assert!(matches("(ab|a)(c|bc)", "abc"), "needs both split choices to be explored");
    assert!(matches("(a|ab)(bc|c)", "abc"));
    assert!(!matches("(ab|a)(c|bc)", "ab"));
}
