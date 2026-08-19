use glob_match::glob_match;

#[test]
fn class_edge_literals() {
    // ']' first in the class is literal
    assert!(glob_match("[]a]x", "]x"));
    assert!(glob_match("[]a]x", "ax"));
    assert!(!glob_match("[]a]x", "bx"));
    // '-' first or last is literal
    assert!(glob_match("[a-]z", "-z"));
    assert!(glob_match("[a-]z", "az"));
    assert!(glob_match("[-a]z", "-z"));
    assert!(!glob_match("[a-]z", "bz"));
    // negated with literal ']'
    assert!(glob_match("[!]]x", "ax"));
    assert!(!glob_match("[!]]x", "]x"));
}

#[test]
fn invalid_patterns_match_nothing() {
    assert!(!glob_match("[abc", "[abc"));
    assert!(!glob_match("[abc", "a"));
    assert!(!glob_match("x[z-a]y", "xmy"));
    assert!(!glob_match("x[z-a]y", "x[z-a]y"));
    assert!(!glob_match("a/[", "a/["));
}

#[test]
fn double_star_only_special_as_whole_segment() {
    assert!(glob_match("a**b", "ab"));
    assert!(glob_match("a**b", "axxb"));
    assert!(!glob_match("a**b", "a/b"));
    assert!(!glob_match("x**", "x/y"));
    assert!(glob_match("x**", "xanything"));
}

#[test]
fn multiple_double_stars() {
    assert!(glob_match("**/x/**", "a/x/b"));
    assert!(glob_match("**/x/**", "x/b"));
    assert!(glob_match("**/x/**", "a/b/x"));
    assert!(glob_match("**/x/**", "x"));
    assert!(!glob_match("**/x/**", "a/b/c"));
    assert!(glob_match("**/**", "a"));
    assert!(glob_match("**/**", "a/b/c"));
}

#[test]
fn empty_pattern_and_path() {
    assert!(glob_match("", ""));
    assert!(!glob_match("", "a"));
    assert!(!glob_match("a", ""));
    assert!(glob_match("*", ""));
}

#[test]
fn backtracking_star_combinations() {
    assert!(glob_match("*a*a*", "banana"));
    assert!(!glob_match("*a*a*a*a*", "banana"));
    assert!(glob_match("x*y*z", "x123y456z"));
    assert!(!glob_match("x*y*z", "x123z456y"));
}

#[test]
fn unicode_paths() {
    assert!(glob_match("données/*.csv", "données/été.csv"));
    assert!(glob_match("?ř?", "křk"));
}
