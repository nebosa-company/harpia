//! A generic least-recently-used cache with explicit recency semantics.

use std::collections::HashMap;
use std::hash::Hash;

/// Fixed-capacity LRU cache. `get`/`put` refresh recency; `peek`,
/// `contains` and `remove` do not.
pub struct LruCache<K, V> {
    map: HashMap<K, V>,
    /// Recency order: front = least recently used, back = most recent.
    order: Vec<K>,
    cap: usize,
}

impl<K: Eq + Hash + Clone, V> LruCache<K, V> {
    /// Empty cache holding at most `capacity` entries (`capacity >= 1`).
    pub fn new(capacity: usize) -> Self {
        LruCache { map: HashMap::new(), order: Vec::new(), cap: capacity }
    }

    fn touch(&mut self, key: &K) {
        if let Some(pos) = self.order.iter().position(|k| k == key) {
            let k = self.order.remove(pos);
            self.order.push(k);
        }
    }

    /// Number of live entries.
    pub fn len(&self) -> usize {
        self.map.len()
    }

    /// Whether the cache is empty.
    pub fn is_empty(&self) -> bool {
        self.map.is_empty()
    }

    /// The fixed capacity.
    pub fn capacity(&self) -> usize {
        self.cap
    }

    /// Value for `key`, refreshing the entry to most-recently-used.
    pub fn get(&mut self, key: &K) -> Option<&V> {
        if self.map.contains_key(key) {
            self.touch(key);
            self.map.get(key)
        } else {
            None
        }
    }

    /// Value for `key` WITHOUT refreshing recency.
    pub fn peek(&self, key: &K) -> Option<&V> {
        self.map.get(key)
    }

    /// Membership test WITHOUT refreshing recency.
    pub fn contains(&self, key: &K) -> bool {
        self.map.contains_key(key)
    }

    /// Insert or update.
    pub fn put(&mut self, key: K, value: V) -> Option<(K, V)> {
        if self.map.contains_key(&key) {
            self.map.insert(key.clone(), value);
            self.touch(&key);
            return None;
        }
        let evicted = if self.map.len() == self.cap {
            let victim = self.order.remove(0);
            let value = self.map.remove(&victim).expect("order/map desync");
            Some((victim, value))
        } else {
            None
        };
        self.order.push(key.clone());
        self.map.insert(key, value);
        evicted
    }

    /// Remove `key`, returning its value.
    pub fn remove(&mut self, key: &K) -> Option<V> {
        let value = self.map.remove(key)?;
        if let Some(pos) = self.order.iter().position(|k| k == key) {
            self.order.remove(pos);
        }
        Some(value)
    }
}
