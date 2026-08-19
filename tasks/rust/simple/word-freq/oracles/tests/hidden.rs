use word_freq::{tokenize, top_words};

#[test]
fn tokenize_lowercases_and_splits() {
    assert_eq!(tokenize("Hello, World! HELLO?"), vec!["hello", "world", "hello"]);
}

#[test]
fn tokenize_treats_digits_as_word_chars() {
    assert_eq!(tokenize("abc123 x-y 42"), vec!["abc123", "x", "y", "42"]);
}

#[test]
fn tokenize_empty_and_symbol_only() {
    assert!(tokenize("").is_empty());
    assert!(tokenize("... !!! ---").is_empty());
}

#[test]
fn tokenize_preserves_order() {
    assert_eq!(tokenize("one two one"), vec!["one", "two", "one"]);
}

#[test]
fn top_words_orders_by_count_then_alpha() {
    let text = "b a b c a b";
    assert_eq!(
        top_words(text, 10),
        vec![("b".to_string(), 3), ("a".to_string(), 2), ("c".to_string(), 1)]
    );
}

#[test]
fn top_words_tie_break_is_alphabetical() {
    let text = "pear apple pear apple mango";
    assert_eq!(
        top_words(text, 2),
        vec![("apple".to_string(), 2), ("pear".to_string(), 2)]
    );
}

#[test]
fn top_words_truncates_to_n() {
    let text = "a b c d";
    assert_eq!(top_words(text, 2).len(), 2);
    assert!(top_words(text, 0).is_empty());
    assert_eq!(top_words(text, 100).len(), 4);
}

#[test]
fn top_words_is_case_insensitive() {
    assert_eq!(top_words("Rust rust RUST", 1), vec![("rust".to_string(), 3)]);
}
