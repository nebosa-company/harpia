//! Turn arbitrary text into URL slugs restricted to `[a-z0-9-]`.

fn transliterate(ch: char) -> Option<&'static str> {
    Some(match ch {
        'à' | 'á' | 'â' | 'ã' | 'ä' | 'å' | 'ā' => "a",
        'ç' | 'ć' | 'č' => "c",
        'è' | 'é' | 'ê' | 'ë' | 'ē' => "e",
        'ì' | 'í' | 'î' | 'ï' | 'ī' => "i",
        'ñ' | 'ń' => "n",
        'ò' | 'ó' | 'ô' | 'õ' | 'ö' | 'ø' | 'ō' => "o",
        'ù' | 'ú' | 'û' | 'ü' | 'ū' => "u",
        'ý' | 'ÿ' => "y",
        'š' => "s",
        'ž' | 'ź' => "z",
        'ł' => "l",
        'đ' => "d",
        'ß' => "ss",
        'æ' => "ae",
        'œ' => "oe",
        _ => return None,
    })
}

/// Slugify `input`.
pub fn slugify(input: &str) -> String {
    let mut out = String::new();
    let mut pending_sep = false;
    for lower in input.chars().flat_map(|c| c.to_lowercase()) {
        let mapped: String = match transliterate(lower) {
            Some(s) => s.to_string(),
            None => lower.to_string(),
        };
        for ch in mapped.chars() {
            if ch.is_ascii_alphanumeric() {
                if pending_sep && !out.is_empty() {
                    out.push('-');
                }
                pending_sep = false;
                out.push(ch);
            } else {
                pending_sep = true;
            }
        }
    }
    out
}
