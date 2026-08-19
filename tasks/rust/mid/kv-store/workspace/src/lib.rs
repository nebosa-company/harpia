//! Append-only, tab-separated persistent KV store with compaction.

use std::path::Path;

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

/// A key-value store backed by an append-only log file.
pub struct KvStore {
    _todo: std::marker::PhantomData<()>,
}

impl KvStore {
    /// Open (creating if absent) and replay the log at `path`.
    pub fn open(path: &Path) -> Result<KvStore, KvError> {
        let _ = path;
        todo!("open and replay the log")
    }

    /// Current value for `key` (memory only, no I/O).
    pub fn get(&self, key: &str) -> Option<&str> {
        let _ = key;
        todo!("look up a value")
    }

    /// Append a set record and update memory.
    pub fn set(&mut self, key: &str, value: &str) -> Result<(), KvError> {
        let _ = (key, value);
        todo!("persist a set")
    }

    /// Append a delete record if the key exists; Ok(false) when absent.
    pub fn remove(&mut self, key: &str) -> Result<bool, KvError> {
        let _ = key;
        todo!("persist a delete")
    }

    /// Number of live keys.
    pub fn len(&self) -> usize {
        todo!("report the length")
    }

    /// Whether no keys are live.
    pub fn is_empty(&self) -> bool {
        todo!("report emptiness")
    }

    /// Live keys, sorted ascending.
    pub fn keys(&self) -> Vec<&str> {
        todo!("list the keys")
    }

    /// Rewrite the log to one sorted S record per live key.
    pub fn compact(&mut self) -> Result<(), KvError> {
        todo!("compact the log")
    }
}
