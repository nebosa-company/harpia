//! SQLite persistence for Harpia. One file per bench database; WAL mode;
//! every write inside a transaction so a killed run never corrupts a round.

use anyhow::Result;
use rusqlite::Connection;
use std::path::Path;

pub const SCHEMA: &str = include_str!("schema.sql");

pub struct Store {
    pub conn: Connection,
}

impl Store {
    pub fn open(path: &Path) -> Result<Self> {
        let conn = Connection::open(path)?;
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;
        conn.pragma_update(None, "foreign_keys", "ON")?;
        conn.execute_batch(SCHEMA)?;
        Ok(Self { conn })
    }

    pub fn open_in_memory() -> Result<Self> {
        let conn = Connection::open_in_memory()?;
        conn.pragma_update(None, "foreign_keys", "ON")?;
        conn.execute_batch(SCHEMA)?;
        Ok(Self { conn })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn schema_applies_clean() {
        Store::open_in_memory().unwrap();
    }
}
