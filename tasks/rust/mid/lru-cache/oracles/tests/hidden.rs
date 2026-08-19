use lru_cache::LruCache;

#[test]
fn insert_and_lookup() {
    let mut c: LruCache<&str, i32> = LruCache::new(3);
    assert_eq!(c.put("a", 1), None);
    assert_eq!(c.put("b", 2), None);
    assert_eq!(c.get(&"a"), Some(&1));
    assert_eq!(c.get(&"b"), Some(&2));
    assert_eq!(c.get(&"zz"), None);
    assert_eq!(c.len(), 2);
}

#[test]
fn eviction_removes_least_recently_used() {
    let mut c: LruCache<&str, i32> = LruCache::new(2);
    c.put("a", 1);
    c.put("b", 2);
    let evicted = c.put("c", 3);
    assert_eq!(evicted, Some(("a", 1)));
    assert!(!c.contains(&"a"));
    assert!(c.contains(&"b"));
    assert!(c.contains(&"c"));
}

#[test]
fn get_refreshes_recency() {
    let mut c: LruCache<&str, i32> = LruCache::new(2);
    c.put("a", 1);
    c.put("b", 2);
    assert_eq!(c.get(&"a"), Some(&1)); // "a" is now most recent
    let evicted = c.put("c", 3);
    assert_eq!(evicted, Some(("b", 2)));
    assert!(c.contains(&"a"));
}

#[test]
fn put_update_refreshes_and_returns_none() {
    let mut c: LruCache<&str, i32> = LruCache::new(2);
    c.put("a", 1);
    c.put("b", 2);
    assert_eq!(c.put("a", 10), None); // update, "a" most recent
    assert_eq!(c.len(), 2);
    let evicted = c.put("c", 3);
    assert_eq!(evicted, Some(("b", 2)));
    assert_eq!(c.peek(&"a"), Some(&10));
}

#[test]
fn eviction_chain_follows_recency_order() {
    let mut c: LruCache<u32, u32> = LruCache::new(3);
    c.put(1, 100);
    c.put(2, 200);
    c.put(3, 300);
    c.get(&1);
    c.get(&3);
    // Recency (old -> new): 2, 1, 3
    assert_eq!(c.put(4, 400), Some((2, 200)));
    assert_eq!(c.put(5, 500), Some((1, 100)));
    assert_eq!(c.put(6, 600), Some((3, 300)));
}
