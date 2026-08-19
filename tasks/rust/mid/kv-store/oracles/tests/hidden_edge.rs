use kv_store::{KvError, KvStore};
use std::path::PathBuf;

fn temp_db(name: &str) -> PathBuf {
    let dir = std::path::Path::new("target").join("test-tmp").join(name);
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    dir.join("db.log")
}

#[test]
fn compaction_produces_sorted_live_records() {
    let path = temp_db("edge-compact");
    let mut kv = KvStore::open(&path).unwrap();
    kv.set("zebra", "z").unwrap();
    kv.set("apple", "a").unwrap();
    kv.set("mango", "m").unwrap();
    kv.set("apple", "a2").unwrap();
    kv.remove("mango").unwrap();
    kv.compact().unwrap();
    let body = std::fs::read_to_string(&path).unwrap();
    assert_eq!(body, "S\tapple\ta2\nS\tzebra\tz\n");
    assert_eq!(kv.get("apple"), Some("a2"));
    assert_eq!(kv.len(), 2);
}

#[test]
fn compaction_shrinks_the_file() {
    let path = temp_db("edge-shrink");
    let mut kv = KvStore::open(&path).unwrap();
    for i in 0..50 {
        kv.set("hot", &format!("v{i}")).unwrap();
    }
    let before = std::fs::metadata(&path).unwrap().len();
    kv.compact().unwrap();
    let after = std::fs::metadata(&path).unwrap().len();
    assert!(after < before, "compaction must shrink {before} -> {after}");
    assert_eq!(std::fs::read_to_string(&path).unwrap(), "S\thot\tv49\n");
}

#[test]
fn reopen_after_compaction_and_further_appends() {
    let path = temp_db("edge-compact-reopen");
    {
        let mut kv = KvStore::open(&path).unwrap();
        kv.set("a", "1").unwrap();
        kv.set("b", "2").unwrap();
        kv.remove("a").unwrap();
        kv.compact().unwrap();
        kv.set("c", "3").unwrap();
    }
    let kv = KvStore::open(&path).unwrap();
    assert_eq!(kv.keys(), vec!["b", "c"]);
    let body = std::fs::read_to_string(&path).unwrap();
    assert_eq!(body, "S\tb\t2\nS\tc\t3\n");
}

#[test]
fn validation_rejects_bad_keys_and_values_without_writing() {
    let path = temp_db("edge-validate");
    let mut kv = KvStore::open(&path).unwrap();
    kv.set("good", "fine").unwrap();
    let before = std::fs::read_to_string(&path).unwrap();
    assert!(matches!(kv.set("", "v"), Err(KvError::InvalidKey)));
    assert!(matches!(kv.set("ta\tb", "v"), Err(KvError::InvalidKey)));
    assert!(matches!(kv.set("k", "line\nbreak"), Err(KvError::InvalidValue)));
    assert!(matches!(kv.set("k", "cr\rhere"), Err(KvError::InvalidValue)));
    assert!(matches!(kv.remove("bad\tkey"), Err(KvError::InvalidKey)));
    let after = std::fs::read_to_string(&path).unwrap();
    assert_eq!(before, after, "validation failures must not touch the file");
    assert_eq!(kv.len(), 1);
}

#[test]
fn empty_values_and_unicode_round_trip() {
    let path = temp_db("edge-unicode");
    {
        let mut kv = KvStore::open(&path).unwrap();
        kv.set("empty", "").unwrap();
        kv.set("città", "Zürich ✓").unwrap();
    }
    let kv = KvStore::open(&path).unwrap();
    assert_eq!(kv.get("empty"), Some(""));
    assert_eq!(kv.get("città"), Some("Zürich ✓"));
}

#[test]
fn compact_empty_store_gives_empty_file() {
    let path = temp_db("edge-compact-empty");
    let mut kv = KvStore::open(&path).unwrap();
    kv.set("a", "1").unwrap();
    kv.remove("a").unwrap();
    kv.compact().unwrap();
    assert_eq!(std::fs::read_to_string(&path).unwrap(), "");
    let kv2 = KvStore::open(&path).unwrap();
    assert!(kv2.is_empty());
}

#[test]
fn missing_trailing_newline_is_tolerated() {
    let path = temp_db("edge-no-trailing-lf");
    std::fs::write(&path, "S\ta\t1\nS\tb\t2").unwrap();
    let kv = KvStore::open(&path).unwrap();
    assert_eq!(kv.get("b"), Some("2"));
    assert_eq!(kv.len(), 2);
}
