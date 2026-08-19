use lru_cache::LruCache;

#[test]
fn peek_and_contains_do_not_refresh() {
    let mut c: LruCache<&str, i32> = LruCache::new(2);
    c.put("a", 1);
    c.put("b", 2);
    assert_eq!(c.peek(&"a"), Some(&1));
    assert!(c.contains(&"a"));
    // "a" is still least recently used.
    assert_eq!(c.put("c", 3), Some(("a", 1)));
}

#[test]
fn remove_frees_a_slot_without_eviction() {
    let mut c: LruCache<&str, i32> = LruCache::new(2);
    c.put("a", 1);
    c.put("b", 2);
    assert_eq!(c.remove(&"a"), Some(1));
    assert_eq!(c.len(), 1);
    assert_eq!(c.put("c", 3), None); // no eviction needed
    assert_eq!(c.remove(&"zz"), None);
    assert_eq!(c.len(), 2);
}

#[test]
fn capacity_one_cache_churns() {
    let mut c: LruCache<u32, &str> = LruCache::new(1);
    assert_eq!(c.put(1, "one"), None);
    assert_eq!(c.put(2, "two"), Some((1, "one")));
    assert_eq!(c.put(3, "three"), Some((2, "two")));
    assert_eq!(c.get(&3), Some(&"three"));
    assert_eq!(c.len(), 1);
    assert_eq!(c.capacity(), 1);
}

#[test]
fn repeated_updates_never_evict() {
    let mut c: LruCache<&str, i32> = LruCache::new(2);
    c.put("a", 1);
    c.put("b", 2);
    for i in 0..10 {
        assert_eq!(c.put("a", i), None);
        assert_eq!(c.put("b", i * 10), None);
    }
    assert_eq!(c.len(), 2);
    assert_eq!(c.peek(&"a"), Some(&9));
    assert_eq!(c.peek(&"b"), Some(&90));
}

#[test]
fn accessors() {
    let mut c: LruCache<u8, u8> = LruCache::new(4);
    assert!(c.is_empty());
    assert_eq!(c.capacity(), 4);
    c.put(1, 1);
    assert!(!c.is_empty());
    assert_eq!(c.len(), 1);
    c.remove(&1);
    assert!(c.is_empty());
}

#[test]
fn get_on_missing_key_does_not_disturb_order() {
    let mut c: LruCache<&str, i32> = LruCache::new(2);
    c.put("a", 1);
    c.put("b", 2);
    assert_eq!(c.get(&"nope"), None);
    assert_eq!(c.put("c", 3), Some(("a", 1)));
}

#[test]
fn owned_string_keys_work() {
    let mut c: LruCache<String, Vec<u8>> = LruCache::new(2);
    c.put("k1".to_string(), vec![1]);
    c.put("k2".to_string(), vec![2]);
    let evicted = c.put("k3".to_string(), vec![3]);
    assert_eq!(evicted, Some(("k1".to_string(), vec![1])));
}
