use json_flatten::flatten;
use std::collections::BTreeMap;

fn map(pairs: &[(&str, &str)]) -> BTreeMap<String, String> {
    pairs.iter().map(|(k, v)| (k.to_string(), v.to_string())).collect()
}

#[test]
fn string_escapes_unescape() {
    let out = flatten(r#"{"s": "a\"b\\c\nd\te\/f"}"#).unwrap();
    assert_eq!(out, map(&[("s", "a\"b\\c\nd\te/f")]));
}

#[test]
fn whitespace_everywhere() {
    let out = flatten("  {\n\t\"a\" :\r\n [ 1 ,\t2 ] , \"b\" : { \"c\" : \"x\" }\n}  ").unwrap();
    assert_eq!(out, map(&[("a.0", "1"), ("a.1", "2"), ("b.c", "x")]));
}

#[test]
fn empty_containers_contribute_nothing() {
    let out = flatten(r#"{"a": {}, "b": [], "c": 1}"#).unwrap();
    assert_eq!(out, map(&[("c", "1")]));
}

#[test]
fn duplicate_keys_later_wins() {
    let out = flatten(r#"{"a": 1, "a": 2}"#).unwrap();
    assert_eq!(out, map(&[("a", "2")]));
}

#[test]
fn unicode_strings_pass_through() {
    let out = flatten(r#"{"città": "Zürich ✓"}"#).unwrap();
    assert_eq!(out, map(&[("città", "Zürich ✓")]));
}

#[test]
fn malformed_inputs_error() {
    for bad in [
        "",
        "   ",
        "[1, 2]",
        "42",
        "\"str\"",
        "{",
        "{\"a\"}",
        "{\"a\":}",
        "{\"a\":1,}",
        "{\"a\":1} extra",
        "{'a': 1}",
        "{\"a\": tru}",
        "{\"a\": \"\\q\"}",
        "{\"a\": .5}",
        "{\"a\": 1.}",
        "{\"a\": 1e}",
        "{\"a\": \"unterminated}",
    ] {
        assert!(flatten(bad).is_err(), "accepted {bad:?}");
    }
}

#[test]
fn deep_nesting_works() {
    let src = r#"{"l1": {"l2": {"l3": {"l4": {"l5": [0, {"leaf": "deep"}]}}}}}"#;
    let out = flatten(src).unwrap();
    assert_eq!(out, map(&[("l1.l2.l3.l4.l5.0", "0"), ("l1.l2.l3.l4.l5.1.leaf", "deep")]));
}
