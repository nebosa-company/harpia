use json_flatten::flatten;
use std::collections::BTreeMap;

fn map(pairs: &[(&str, &str)]) -> BTreeMap<String, String> {
    pairs.iter().map(|(k, v)| (k.to_string(), v.to_string())).collect()
}

#[test]
fn flat_object() {
    let out = flatten(r#"{"a": 1, "b": "two", "c": true, "d": null}"#).unwrap();
    assert_eq!(out, map(&[("a", "1"), ("b", "two"), ("c", "true"), ("d", "null")]));
}

#[test]
fn nested_objects_join_with_dots() {
    let out = flatten(r#"{"a": {"b": {"c": 42}}, "x": {"y": false}}"#).unwrap();
    assert_eq!(out, map(&[("a.b.c", "42"), ("x.y", "false")]));
}

#[test]
fn arrays_use_indices() {
    let out = flatten(r#"{"tags": ["x", "y"], "grid": [[1, 2], [3]]}"#).unwrap();
    assert_eq!(
        out,
        map(&[
            ("tags.0", "x"),
            ("tags.1", "y"),
            ("grid.0.0", "1"),
            ("grid.0.1", "2"),
            ("grid.1.0", "3"),
        ])
    );
}

#[test]
fn arrays_of_objects() {
    let out = flatten(r#"{"a": [{"b": 1}, {"c": [2, 3]}]}"#).unwrap();
    assert_eq!(out, map(&[("a.0.b", "1"), ("a.1.c.0", "2"), ("a.1.c.1", "3")]));
}

#[test]
fn number_tokens_stay_verbatim() {
    let out = flatten(r#"{"a": 1e2, "b": -0.5, "c": 12345678901234567890, "d": 2.5E-3}"#).unwrap();
    assert_eq!(
        out,
        map(&[("a", "1e2"), ("b", "-0.5"), ("c", "12345678901234567890"), ("d", "2.5E-3")])
    );
}

#[test]
fn empty_root_object() {
    assert!(flatten("{}").unwrap().is_empty());
}
