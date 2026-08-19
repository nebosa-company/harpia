use slugify::slugify;

#[test]
fn basic_lowercasing_and_separators() {
    assert_eq!(slugify("Hello, World!"), "hello-world");
    assert_eq!(slugify("Rust 2026 Release"), "rust-2026-release");
}

#[test]
fn accents_transliterate() {
    assert_eq!(slugify("Crème Brûlée"), "creme-brulee");
    assert_eq!(slugify("São Paulo"), "sao-paulo");
    assert_eq!(slugify("El Niño"), "el-nino");
}

#[test]
fn multi_char_expansions() {
    assert_eq!(slugify("Straße"), "strasse");
    assert_eq!(slugify("Æther Œuvre"), "aether-oeuvre");
}

#[test]
fn separator_runs_collapse() {
    assert_eq!(slugify("a --- b___c"), "a-b-c");
    assert_eq!(slugify("  spaced   out  "), "spaced-out");
}

#[test]
fn trims_edge_hyphens() {
    assert_eq!(slugify("--edge--"), "edge");
    assert_eq!(slugify("!leading and trailing!"), "leading-and-trailing");
}

#[test]
fn digits_survive() {
    assert_eq!(slugify("Version 2.5.1"), "version-2-5-1");
}
