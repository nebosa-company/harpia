//! A generic least-recently-used cache with explicit recency semantics.

use std::hash::Hash;

/// Fixed-capacity LRU cache. `get`/`put` refresh recency; `peek`,
/// `contains` and `remove` do not.
pub struct LruCache<K, V> {
    _marker: std::marker::PhantomData<(K, V)>,
}

impl<K: Eq + Hash + Clone, V> LruCache<K, V> {
    /// Empty cache holding at most `capacity` entries (`capacity >= 1`).
    pub fn new(capacity: usize) -> Self {
        let _ = capacity;
        todo!("create the cache")
    }

    /// Number of live entries.
    pub fn len(&self) -> usize {
        todo!("report the length")
    }

    /// Whether the cache is empty.
    pub fn is_empty(&self) -> bool {
        todo!("report emptiness")
    }

    /// The fixed capacity.
    pub fn capacity(&self) -> usize {
        todo!("report the capacity")
    }

    /// Value for `key`, refreshing the entry to most-recently-used.
    pub fn get(&mut self, key: &K) -> Option<&V> {
        let _ = key;
        todo!("look up and refresh")
    }

    /// Value for `key` WITHOUT refreshing recency.
    pub fn peek(&self, key: &K) -> Option<&V> {
        let _ = key;
        todo!("look up without refreshing")
    }

    /// Membership test WITHOUT refreshing recency.
    pub fn contains(&self, key: &K) -> bool {
        let _ = key;
        todo!("test membership")
    }

    /// Insert or update. Updates refresh and return None; inserts into a
    /// full cache evict and return the least-recently-used pair.
    pub fn put(&mut self, key: K, value: V) -> Option<(K, V)> {
        let _ = (key, value);
        todo!("insert or update")
    }

    /// Remove `key`, returning its value.
    pub fn remove(&mut self, key: &K) -> Option<V> {
        let _ = key;
        todo!("remove the entry")
    }
}
