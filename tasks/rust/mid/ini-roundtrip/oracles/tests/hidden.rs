use ini::{Ini, IniError};

#[test]
fn basic_parse_and_get() {
    let doc = Ini::parse("[server]\nhost = example.com\nport = 8080\n[client]\nretries = 3\n")
        .unwrap();
    assert_eq!(doc.get("server", "host"), Some("example.com"));
    assert_eq!(doc.get("server", "port"), Some("8080"));
    assert_eq!(doc.get("client", "retries"), Some("3"));
    assert_eq!(doc.get("server", "missing"), None);
    assert_eq!(doc.get("nope", "host"), None);
}

#[test]
fn comments_and_blanks_are_skipped() {
    let doc = Ini::parse("; leading comment\n\n[a]\n# note\n  ; indented comment\nx = 1\n\n")
        .unwrap();
    assert_eq!(doc.get("a", "x"), Some("1"));
    assert_eq!(doc.sections(), vec!["a"]);
    assert_eq!(doc.keys("a"), vec!["x"]);
}

#[test]
fn trimming_and_first_equals_split() {
    let doc = Ini::parse("[s]\n  spaced key  =  spaced value  \nexpr = a = b\nempty =\n").unwrap();
    assert_eq!(doc.get("s", "spaced key"), Some("spaced value"));
    assert_eq!(doc.get("s", "expr"), Some("a = b"));
    assert_eq!(doc.get("s", "empty"), Some(""));
}

#[test]
fn global_section_keys() {
    let doc = Ini::parse("root = 1\nname = top\n[a]\nx = 2\n").unwrap();
    assert_eq!(doc.get("", "root"), Some("1"));
    assert_eq!(doc.get("", "name"), Some("top"));
    assert_eq!(doc.sections(), vec!["", "a"]);
}

#[test]
fn duplicate_key_updates_in_place() {
    let doc = Ini::parse("[s]\na = 1\nb = 2\na = 3\n").unwrap();
    assert_eq!(doc.get("s", "a"), Some("3"));
    assert_eq!(doc.keys("s"), vec!["a", "b"]);
}

#[test]
fn duplicate_section_reopens() {
    let doc = Ini::parse("[a]\nx = 1\n[b]\ny = 2\n[a]\nz = 3\n").unwrap();
    assert_eq!(doc.sections(), vec!["a", "b"]);
    assert_eq!(doc.keys("a"), vec!["x", "z"]);
    assert_eq!(doc.get("a", "z"), Some("3"));
}

#[test]
fn parse_errors_carry_line_numbers() {
    assert_eq!(Ini::parse("[a]\nno equals here\n"), Err(IniError::BadLine { line: 2 }));
    assert_eq!(Ini::parse("ok = 1\n= no key\n"), Err(IniError::BadLine { line: 2 }));
    assert_eq!(Ini::parse("\n\n[]\n"), Err(IniError::EmptySection { line: 3 }));
    assert_eq!(Ini::parse("[  ]\n"), Err(IniError::EmptySection { line: 1 }));
    assert_eq!(Ini::parse("[unclosed\n"), Err(IniError::BadLine { line: 1 }));
}

#[test]
fn crlf_input() {
    let doc = Ini::parse("[a]\r\nx = 1\r\ny = 2\r\n").unwrap();
    assert_eq!(doc.get("a", "x"), Some("1"));
    assert_eq!(doc.get("a", "y"), Some("2"));
}
