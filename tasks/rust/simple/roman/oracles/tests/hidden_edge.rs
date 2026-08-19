use roman::{from_roman, to_roman};

#[test]
fn full_round_trip() {
    for n in 1..=3999u32 {
        let encoded = to_roman(n).unwrap_or_else(|| panic!("no encoding for {n}"));
        assert_eq!(from_roman(&encoded), Some(n), "round-trip {n} via {encoded}");
    }
}

#[test]
fn decoder_rejects_non_canonical() {
    for bad in ["IIII", "VV", "LL", "DD", "IC", "XM", "VX", "IVX", "MMMM", "CMCM", "IXIX"] {
        assert_eq!(from_roman(bad), None, "decoding {bad:?}");
    }
}

#[test]
fn decoder_rejects_lowercase() {
    assert_eq!(from_roman("iv"), None);
    assert_eq!(from_roman("mcmxc"), None);
    assert_eq!(from_roman("Xiv"), None);
}

#[test]
fn boundary_values() {
    assert_eq!(to_roman(1000).as_deref(), Some("M"));
    assert_eq!(to_roman(3888).as_deref(), Some("MMMDCCCLXXXVIII"));
    assert_eq!(from_roman("MMMDCCCLXXXVIII"), Some(3888));
}
