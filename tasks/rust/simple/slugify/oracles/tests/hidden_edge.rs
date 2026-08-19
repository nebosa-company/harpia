use slugify::slugify;

#[test]
fn empty_and_symbol_only() {
    assert_eq!(slugify(""), "");
    assert_eq!(slugify("!!!"), "");
    assert_eq!(slugify(" - - - "), "");
}

#[test]
fn unmapped_scripts_are_separators() {
    assert_eq!(slugify("北京 2026"), "2026");
    assert_eq!(slugify("rock & roll 🎸"), "rock-roll");
}

#[test]
fn uppercase_accents_lowercase_first() {
    assert_eq!(slugify("ÑOÑO"), "nono");
    assert_eq!(slugify("ÉTÉ"), "ete");
}

#[test]
fn eastern_european_table_entries() {
    assert_eq!(slugify("Łódź"), "lodz");
    assert_eq!(slugify("Žižka"), "zizka");
    assert_eq!(slugify("Đorđe"), "dorde");
}

#[test]
fn already_clean_input_is_untouched() {
    assert_eq!(slugify("already-clean-slug-42"), "already-clean-slug-42");
}

#[test]
fn single_characters() {
    assert_eq!(slugify("ß"), "ss");
    assert_eq!(slugify("A"), "a");
    assert_eq!(slugify("-"), "");
}
