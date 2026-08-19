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
    /// Parse INI text. See the crate rules for line handling and errors.
    pub fn parse(src: &str) -> Result<Ini, IniError> {
        let _ = src;
        todo!("parse the document")
    }

    /// Value of `key` in `section` ("" = global), if present.
    pub fn get(&self, section: &str, key: &str) -> Option<&str> {
        let _ = (section, key);
        todo!("look up a value")
    }

    /// Set `key` in `section`, overwriting in place or appending; creates
    /// the section if needed ("" is created at the front, others at the end).
    pub fn set(&mut self, section: &str, key: &str, value: &str) {
        let _ = (section, key, value);
        todo!("set a value")
    }

    /// Section names in order of first appearance ("" included when the
    /// global section exists).
    pub fn sections(&self) -> Vec<&str> {
        todo!("list the sections")
    }

    /// Keys of `section` in insertion order; empty for unknown sections.
    pub fn keys(&self, section: &str) -> Vec<&str> {
        let _ = section;
        todo!("list the keys")
    }
}

impl std::fmt::Display for Ini {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let _ = f;
        todo!("serialize canonically")
    }
}
