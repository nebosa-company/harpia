use roman::{from_roman, to_roman};

#[test]
fn known_encodings() {
    let cases = [
        (1, "I"),
        (4, "IV"),
        (9, "IX"),
        (14, "XIV"),
        (40, "XL"),
        (90, "XC"),
        (400, "CD"),
        (900, "CM"),
        (1990, "MCMXC"),
        (2026, "MMXXVI"),
        (3999, "MMMCMXCIX"),
    ];
    for (n, s) in cases {
        assert_eq!(to_roman(n).as_deref(), Some(s), "encoding {n}");
    }
}

#[test]
fn out_of_range_encodes_to_none() {
    assert_eq!(to_roman(0), None);
    assert_eq!(to_roman(4000), None);
    assert_eq!(to_roman(u32::MAX), None);
}

#[test]
fn known_decodings() {
    assert_eq!(from_roman("I"), Some(1));
    assert_eq!(from_roman("XIV"), Some(14));
    assert_eq!(from_roman("MCMXC"), Some(1990));
    assert_eq!(from_roman("MMMCMXCIX"), Some(3999));
}

#[test]
fn decoder_rejects_garbage() {
    for bad in ["", "A", "IIX", "ROME", "M M", " I", "I "] {
        assert_eq!(from_roman(bad), None, "decoding {bad:?}");
    }
}
