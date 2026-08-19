//! Word-frequency reporting: tokenize text and rank words by count.

/// Split `text` into lowercase words, in order of appearance.
pub fn tokenize(text: &str) -> Vec<String> {
    let mut words = Vec::new();
    let mut cur = String::new();
    for ch in text.chars() {
        if ch.is_ascii_alphanumeric() {
            cur.push(ch.to_ascii_lowercase());
        } else if !cur.is_empty() {
            words.push(std::mem::take(&mut cur));
        }
    }
    if !cur.is_empty() {
        words.push(cur);
    }
    words
}

/// The `n` most frequent words, most frequent first, ties alphabetical.
pub fn top_words(text: &str, n: usize) -> Vec<(String, usize)> {
    let mut counts: std::collections::HashMap<String, usize> = std::collections::HashMap::new();
    for w in tokenize(text) {
        *counts.entry(w).or_insert(0) += 1;
    }
    let mut entries: Vec<(String, usize)> = counts.into_iter().collect();
    entries.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    entries.truncate(n);
    entries
}

/// CLI entry point.
pub fn run(args: &[String]) -> i32 {
    let Some(path) = args.first() else {
        eprintln!("usage: word_freq <file> [n]");
        return 2;
    };
    let n = match args.get(1) {
        None => 10,
        Some(raw) => match raw.parse::<usize>() {
            Ok(v) => v,
            Err(_) => {
                eprintln!("invalid count: {raw}");
                return 2;
            }
        },
    };
    let text = match std::fs::read_to_string(path) {
        Ok(t) => t,
        Err(e) => {
            eprintln!("cannot read {path}: {e}");
            return 2;
        }
    };
    for (word, count) in top_words(&text, n) {
        println!("{word} {count}");
    }
    0
}
