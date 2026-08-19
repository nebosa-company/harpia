//! Order-preserving INI documents with a canonical, round-tripping
//! serialization.

/// Parse failures, with 1-based physical line numbers.
#[derive(Debug, PartialEq)]
pub enum IniError {
    /// Not a comment, header, or `key = value` line (or the key is empty).
    BadLine { line: usize },
    /// A `[...]` header with an empty (or whitespace-only) name.
    EmptySection { line: usize },
}

/// An INI document: ordered sections of ordered key/value pairs. The global
/// (header-less) section has the name "".
#[derive(Debug, PartialEq, Clone)]
pub struct Ini {
    sections: Vec<(String, Vec<(String, String)>)>,
}

impl Ini {
    fn section_mut(&mut self, name: &str) -> Option<&mut Vec<(String, String)>> {
        self.sections.iter_mut().find(|(n, _)| n == name).map(|(_, e)| e)
    }

    fn section(&self, name: &str) -> Option<&Vec<(String, String)>> {
        self.sections.iter().find(|(n, _)| n == name).map(|(_, e)| e)
    }

    /// Parse INI text.
    pub fn parse(src: &str) -> Result<Ini, IniError> {
        let mut ini = Ini { sections: Vec::new() };
        let mut current = String::new(); // current section name; "" = global
        for (idx, raw) in src.split('\n').enumerate() {
            let line_no = idx + 1;
            let line = raw.strip_suffix('\r').unwrap_or(raw).trim();
            if line.is_empty() || line.starts_with(';') || line.starts_with('#') {
                continue;
            }
            if let Some(rest) = line.strip_prefix('[') {
                let Some(name) = rest.strip_suffix(']') else {
                    return Err(IniError::BadLine { line: line_no });
                };
                let name = name.trim();
                if name.is_empty() {
                    return Err(IniError::EmptySection { line: line_no });
                }
                current = name.to_string();
                if ini.section(name).is_none() {
                    ini.sections.push((name.to_string(), Vec::new()));
                }
                continue;
            }
            let Some((key, value)) = line.split_once('=') else {
                return Err(IniError::BadLine { line: line_no });
            };
            let (key, value) = (key.trim(), value.trim());
            if key.is_empty() {
                return Err(IniError::BadLine { line: line_no });
            }
            ini.set(&current.clone(), key, value);
        }
        Ok(ini)
    }

    /// Value of `key` in `section` ("" = global), if present.
    pub fn get(&self, section: &str, key: &str) -> Option<&str> {
        self.section(section)?
            .iter()
            .find(|(k, _)| k == key)
            .map(|(_, v)| v.as_str())
    }

    /// Set `key` in `section`, overwriting in place or appending.
    pub fn set(&mut self, section: &str, key: &str, value: &str) {
        if self.section(section).is_none() {
            let entry = (section.to_string(), Vec::new());
            if section.is_empty() {
                self.sections.insert(0, entry);
            } else {
                self.sections.push(entry);
            }
        }
        let entries = self.section_mut(section).expect("just ensured");
        match entries.iter_mut().find(|(k, _)| k == key) {
            Some((_, v)) => *v = value.to_string(),
            None => entries.push((key.to_string(), value.to_string())),
        }
    }

    /// Section names in order of first appearance.
    pub fn sections(&self) -> Vec<&str> {
        self.sections.iter().map(|(n, _)| n.as_str()).collect()
    }

    /// Keys of `section` in insertion order; empty for unknown sections.
    pub fn keys(&self, section: &str) -> Vec<&str> {
        self.section(section)
            .map(|entries| entries.iter().map(|(k, _)| k.as_str()).collect())
            .unwrap_or_default()
    }
}

impl std::fmt::Display for Ini {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let mut first_block = true;
        for (name, entries) in &self.sections {
            if !first_block {
                writeln!(f)?;
            }
            first_block = false;
            if !name.is_empty() {
                writeln!(f, "[{name}]")?;
            }
            for (key, value) in entries {
                if value.is_empty() {
                    writeln!(f, "{key} =")?;
                } else {
                    writeln!(f, "{key} = {value}")?;
                }
            }
        }
        Ok(())
    }
}
