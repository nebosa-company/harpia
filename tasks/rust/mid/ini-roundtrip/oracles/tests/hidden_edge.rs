use ini::Ini;

#[test]
fn canonical_display_exact() {
    let doc = Ini::parse("root = 1\n\n[alpha]\nx=1\ny =  two\n\n[beta]\nz =\n").unwrap();
    assert_eq!(
        doc.to_string(),
        "root = 1\n\n[alpha]\nx = 1\ny = two\n\n[beta]\nz =\n"
    );
}

#[test]
fn empty_ini_displays_as_empty_string() {
    let doc = Ini::parse("").unwrap();
    assert_eq!(doc.to_string(), "");
    let doc = Ini::parse("; only comments\n\n").unwrap();
    assert_eq!(doc.to_string(), "");
}

#[test]
fn round_trip_fixtures() {
    let fixtures = [
        "a = 1\n",
        "[s]\nk = v\n",
        "root = 1\n[a]\nx = 1\n[b]\ny = 2\n",
        "; comment\n[weird]\n  padded   =   value with spaces  \nexpr = a=b=c\nempty =\n",
        "[dup]\na = 1\na = 2\n[dup]\nb = 3\n",
        "[only-header]\n",
    ];
    for src in fixtures {
        let first = Ini::parse(src).unwrap();
        let printed = first.to_string();
        let second = Ini::parse(&printed).unwrap();
        assert_eq!(second, first, "round-trip failed for {src:?} -> {printed:?}");
    }
}

#[test]
fn set_updates_in_place_and_appends() {
    let mut doc = Ini::parse("[s]\na = 1\nb = 2\n").unwrap();
    doc.set("s", "a", "changed");
    assert_eq!(doc.keys("s"), vec!["a", "b"]);
    assert_eq!(doc.get("s", "a"), Some("changed"));
    doc.set("s", "c", "3");
    assert_eq!(doc.keys("s"), vec!["a", "b", "c"]);
}

#[test]
fn set_creates_sections_in_the_right_place() {
    let mut doc = Ini::parse("[a]\nx = 1\n").unwrap();
    doc.set("b", "y", "2");
    assert_eq!(doc.sections(), vec!["a", "b"]);
    doc.set("", "root", "top");
    assert_eq!(doc.sections(), vec!["", "a", "b"]);
    assert_eq!(
        doc.to_string(),
        "root = top\n\n[a]\nx = 1\n\n[b]\ny = 2\n"
    );
}

#[test]
fn set_then_round_trip() {
    let mut doc = Ini::parse("").unwrap();
    doc.set("net", "host", "example.org");
    doc.set("net", "port", "443");
    doc.set("", "version", "2");
    doc.set("net", "host", "example.com");
    let reparsed = Ini::parse(&doc.to_string()).unwrap();
    assert_eq!(reparsed, doc);
    assert_eq!(reparsed.get("net", "host"), Some("example.com"));
    assert_eq!(reparsed.sections(), vec!["", "net"]);
}

#[test]
fn headers_with_padding_and_empty_sections_round_trip() {
    let doc = Ini::parse("  [ padded ]  \nk = 1\n[empty]\n").unwrap();
    assert_eq!(doc.sections(), vec!["padded", "empty"]);
    assert_eq!(doc.get("padded", "k"), Some("1"));
    assert_eq!(doc.keys("empty"), Vec::<&str>::new());
    let reparsed = Ini::parse(&doc.to_string()).unwrap();
    assert_eq!(reparsed, doc);
}
