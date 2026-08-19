//! Turn arbitrary text into URL slugs restricted to `[a-z0-9-]`.

/// Slugify `input`: lowercase, transliterate a small accent table to ASCII,
/// treat everything non-alphanumeric as a separator, collapse separators
/// into single hyphens, and trim hyphens at both ends.
pub fn slugify(input: &str) -> String {
    let _ = input;
    todo!("build the slug")
}
