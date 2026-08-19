//! Append-only, tab-separated persistent KV store with compaction.

use std::collections::BTreeMap;
use std::io::Write;
use std::path::{Path, PathBuf};

/// Store failures.
#[derive(Debug)]
pub enum KvError {
    /// Underlying I/O failure.
    Io(std::io::Error),
    /// A malformed record during replay (1-based line number).
    Corrupt { line: usize },
    /// Empty key, or key containing tab/newline/CR.
    InvalidKey,
    /// Value containing tab/newline/CR.
    InvalidValue,
}

impl From<std::io::Error> for KvError {
    fn from(e: std::io::Error) -> Self {
        KvError::Io(e)
    }
}

fn valid_key(key: &str) -> bool {
    !key.is_empty() && !key.contains(['\t', '\n', '\r'])
}

fn valid_value(value: &str) -> bool {
    !value.contains(['\t', '\n', '\r'])
}

/// A key-value store backed by an append-only log file.
pub struct KvStore {
    path: PathBuf,
    map: BTreeMap<String, String>,
}

impl KvStore {
    /// Open (creating if absent) and replay the log at `path`.
    pub fn open(path: &Path) -> Result<KvStore, KvError> {
        if !path.exists() {
            std::fs::write(path, "")?;
        }
        let body = std::fs::read_to_string(path)?;
        let mut map = BTreeMap::new();
        for (idx, line) in body.split('\n').enumerate() {
            if line.is_empty() && idx == body.split('\n').count() - 1 {
                continue; // trailing newline
            }
            let line_no = idx + 1;
            let corrupt = KvError::Corrupt { line: line_no };
            if let Some(rest) = line.strip_prefix("S\t") {
                let Some((key, value)) = rest.split_once('\t') else {
                    return Err(corrupt);
                };
                if !valid_key(key) || !valid_value(value) {
                    return Err(corrupt);
                }
                map.insert(key.to_string(), value.to_string());
            } else if let Some(key) = line.strip_prefix("D\t") {
                if !valid_key(key) {
                    return Err(corrupt);
                }
                map.remove(key);
            } else {
                return Err(corrupt);
            }
        }
        Ok(KvStore { path: path.to_path_buf(), map })
    }

    fn append(&self, record: &str) -> Result<(), KvError> {
        let mut file = std::fs::OpenOptions::new()
            .append(true)
            .create(true)
            .open(&self.path)?;
        file.write_all(record.as_bytes())?;
        Ok(())
    }

    /// Current value for `key` (memory only, no I/O).
    pub fn get(&self, key: &str) -> Option<&str> {
        self.map.get(key).map(|v| v.as_str())
    }

    /// Append a set record and update memory.
    pub fn set(&mut self, key: &str, value: &str) -> Result<(), KvError> {
        if !valid_key(key) {
            return Err(KvError::InvalidKey);
        }
        if !valid_value(value) {
            return Err(KvError::InvalidValue);
        }
        self.append(&format!("S\t{key}\t{value}\n"))?;
        self.map.insert(key.to_string(), value.to_string());
        Ok(())
    }

    /// Append a delete record if the key exists; Ok(false) when absent.
    pub fn remove(&mut self, key: &str) -> Result<bool, KvError> {
        if !valid_key(key) {
            return Err(KvError::InvalidKey);
        }
        if !self.map.contains_key(key) {
            return Ok(false);
        }
        self.append(&format!("D\t{key}\n"))?;
        self.map.remove(key);
        Ok(true)
    }

    /// Number of live keys.
    pub fn len(&self) -> usize {
        self.map.len()
    }

    /// Whether no keys are live.
    pub fn is_empty(&self) -> bool {
        self.map.is_empty()
    }

    /// Live keys, sorted ascending.
    pub fn keys(&self) -> Vec<&str> {
        self.map.keys().map(|k| k.as_str()).collect()
    }

    /// Rewrite the log to one sorted S record per live key.
    pub fn compact(&mut self) -> Result<(), KvError> {
        let mut body = String::new();
        for (key, value) in &self.map {
            body.push_str(&format!("S\t{key}\t{value}\n"));
        }
        std::fs::write(&self.path, body)?;
        Ok(())
    }
}
