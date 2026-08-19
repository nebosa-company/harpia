use kv_store::{KvError, KvStore};
use std::path::PathBuf;

fn temp_db(name: &str) -> PathBuf {
    let dir = std::path::Path::new("target").join("test-tmp").join(name);
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    dir.join("db.log")
}

#[test]
fn set_get_and_overwrite() {
    let path = temp_db("core-set-get");
    let mut kv = KvStore::open(&path).unwrap();
    assert!(kv.is_empty());
    kv.set("alpha", "1").unwrap();
    kv.set("beta", "2").unwrap();
    assert_eq!(kv.get("alpha"), Some("1"));
    kv.set("alpha", "one").unwrap();
    assert_eq!(kv.get("alpha"), Some("one"));
    assert_eq!(kv.get("beta"), Some("2"));
    assert_eq!(kv.get("gamma"), None);
    assert_eq!(kv.len(), 2);
    assert_eq!(kv.keys(), vec!["alpha", "beta"]);
}

#[test]
fn state_survives_reopen() {
    let path = temp_db("core-reopen");
    {
        let mut kv = KvStore::open(&path).unwrap();
        kv.set("k1", "v1").unwrap();
        kv.set("k2", "v2").unwrap();
        kv.set("k1", "v1b").unwrap();
        kv.remove("k2").unwrap();
    }
    let kv = KvStore::open(&path).unwrap();
    assert_eq!(kv.get("k1"), Some("v1b"));
    assert_eq!(kv.get("k2"), None);
    assert_eq!(kv.len(), 1);
}

#[test]
fn remove_semantics() {
    let path = temp_db("core-remove");
    let mut kv = KvStore::open(&path).unwrap();
    kv.set("x", "1").unwrap();
    assert_eq!(kv.remove("x").unwrap(), true);
    assert_eq!(kv.get("x"), None);
    assert_eq!(kv.remove("x").unwrap(), false);
    assert_eq!(kv.remove("never-there").unwrap(), false);
}

#[test]
fn file_format_is_exact() {
    let path = temp_db("core-format");
    let mut kv = KvStore::open(&path).unwrap();
    kv.set("a", "1").unwrap();
    kv.set("b", "2").unwrap();
    kv.remove("a").unwrap();
    kv.set("b", "3").unwrap();
    let body = std::fs::read_to_string(&path).unwrap();
    assert_eq!(body, "S\ta\t1\nS\tb\t2\nD\ta\nS\tb\t3\n");
}

#[test]
fn removed_key_absent_records_nothing() {
    let path = temp_db("core-remove-absent");
    let mut kv = KvStore::open(&path).unwrap();
    kv.set("a", "1").unwrap();
    let before = std::fs::read_to_string(&path).unwrap();
    assert_eq!(kv.remove("ghost").unwrap(), false);
    let after = std::fs::read_to_string(&path).unwrap();
    assert_eq!(before, after, "failed remove must not append");
}

#[test]
fn open_missing_file_creates_empty_store() {
    let path = temp_db("core-fresh");
    let kv = KvStore::open(&path).unwrap();
    assert!(kv.is_empty());
    assert!(path.exists(), "open must create the file");
}

#[test]
fn corrupt_log_reports_line() {
    let path = temp_db("core-corrupt");
    std::fs::write(&path, "S\ta\t1\nWHAT IS THIS\nS\tb\t2\n").unwrap();
    match KvStore::open(&path) {
        Err(KvError::Corrupt { line }) => assert_eq!(line, 2),
        Err(other) => panic!("expected Corrupt, got {other:?}"),
        Ok(_) => panic!("expected Corrupt, got Ok"),
    }
    std::fs::write(&path, "S\tonly-a-key\n").unwrap();
    assert!(matches!(KvStore::open(&path), Err(KvError::Corrupt { line: 1 })));
}
