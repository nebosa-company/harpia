use glob_match::glob_match;

#[test]
fn literal_paths() {
    assert!(glob_match("src/lib.rs", "src/lib.rs"));
    assert!(!glob_match("src/lib.rs", "src/main.rs"));
    assert!(!glob_match("src/lib.rs", "src/lib.rs/extra"));
    assert!(!glob_match("a/b/c", "a/b"));
    assert!(!glob_match("Src", "src"), "case-sensitive");
}

#[test]
fn question_mark_single_non_separator() {
    assert!(glob_match("fil?.txt", "file.txt"));
    assert!(glob_match("???", "abc"));
    assert!(!glob_match("???", "ab"));
    assert!(!glob_match("???", "abcd"));
    assert!(!glob_match("a?c", "a/c"), "? must not match '/'");
    assert!(!glob_match("?", ""));
}

#[test]
fn star_within_a_segment() {
    assert!(glob_match("*.rs", "lib.rs"));
    assert!(glob_match("src/*.rs", "src/lib.rs"));
    assert!(!glob_match("src/*.rs", "src/a/b.rs"), "* must not cross '/'");
    assert!(glob_match("a*b", "ab"), "* matches empty");
    assert!(glob_match("a*b", "axyzb"));
    assert!(!glob_match("a*b", "a/b"));
    assert!(glob_match("*", "anything"));
    assert!(glob_match("*", ""));
    assert!(!glob_match("*", "two/segments"));
}

#[test]
fn character_classes() {
    assert!(glob_match("[abc]x", "ax"));
    assert!(glob_match("[abc]x", "cx"));
    assert!(!glob_match("[abc]x", "dx"));
    assert!(glob_match("v[0-9].log", "v7.log"));
    assert!(!glob_match("v[0-9].log", "vx.log"));
    assert!(glob_match("[a-cx-z]1", "y1"));
    assert!(!glob_match("[a-cx-z]1", "m1"));
}

#[test]
fn negated_classes() {
    assert!(glob_match("[!0-9]x", "ax"));
    assert!(!glob_match("[!0-9]x", "5x"));
    assert!(!glob_match("data[!a]", "data/"), "classes never match '/'");
}

#[test]
fn double_star_spans_segments() {
    assert!(glob_match("a/**/b", "a/b"), "** matches zero segments");
    assert!(glob_match("a/**/b", "a/x/b"));
    assert!(glob_match("a/**/b", "a/x/y/z/b"));
    assert!(!glob_match("a/**/b", "a/x/y/c"));
    assert!(glob_match("**/c", "c"));
    assert!(glob_match("**/c", "x/y/c"));
    assert!(glob_match("a/**", "a"));
    assert!(glob_match("a/**", "a/b/c/d"));
    assert!(glob_match("**", "x/y/z"));
    assert!(glob_match("**", "x"));
}

#[test]
fn mixed_wildcards() {
    assert!(glob_match("src/**/*.rs", "src/lib.rs"));
    assert!(glob_match("src/**/*.rs", "src/a/b/mod.rs"));
    assert!(!glob_match("src/**/*.rs", "src/a/b/mod.txt"));
    assert!(glob_match("**/test?/[0-9]*.log", "deep/tests/1abc.log"));
    assert!(!glob_match("**/test?/[0-9]*.log", "deep/tests/abc.log"));
}
