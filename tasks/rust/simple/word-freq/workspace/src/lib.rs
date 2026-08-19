//! Word-frequency reporting: tokenize text and rank words by count.

/// Split `text` into lowercase words, in order of appearance. A word is a
/// maximal run of ASCII alphanumeric characters; every other character
/// separates words.
pub fn tokenize(text: &str) -> Vec<String> {
    let _ = text;
    todo!("split text into lowercase alphanumeric words")
}

/// The `n` most frequent words in `text`, most frequent first. Ties are
/// broken alphabetically. Returns fewer than `n` entries when the text has
/// fewer distinct words.
pub fn top_words(text: &str, n: usize) -> Vec<(String, usize)> {
    let _ = (text, n);
    todo!("rank words by frequency")
}

/// CLI entry point; `args` are the process arguments after the program name.
/// Usage: `word_freq <file> [n]` (n defaults to 10). Prints one `word count`
/// line per entry to stdout and returns 0; on bad usage or an unreadable
/// file prints to stderr and returns 2.
pub fn run(args: &[String]) -> i32 {
    let _ = args;
    todo!("drive the CLI")
}
