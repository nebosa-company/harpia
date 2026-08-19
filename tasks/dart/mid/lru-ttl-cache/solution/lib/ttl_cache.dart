/// Capacity-bounded cache with per-entry time-to-live.

class _Entry<V> {
  final V value;
  final int stamp;

  _Entry(this.value, this.stamp);
}

/// LRU cache whose entries expire [ttlMs] after their last write.
///
/// The [clock] returns the current time in milliseconds; injecting it keeps
/// eviction behavior fully deterministic for callers.
class TtlCache<K, V> {
  final int capacity;
  final int ttlMs;
  final int Function() clock;
  final Map<K, _Entry<V>> _map = {};

  TtlCache({required this.capacity, required this.ttlMs, required this.clock}) {
    if (capacity < 1) throw ArgumentError('capacity must be >= 1');
    if (ttlMs < 1) throw ArgumentError('ttlMs must be >= 1');
  }

  bool _expired(_Entry<V> entry) => clock() - entry.stamp >= ttlMs;

  void _prune() {
    _map.removeWhere((_, entry) => _expired(entry));
  }

  V? get(K key) {
    final entry = _map[key];
    if (entry == null) return null;
    if (_expired(entry)) {
      _map.remove(key);
      return null;
    }
    // Refresh recency: reinsertion moves the key to the back of the
    // insertion order, which is the most-recently-used position.
    _map.remove(key);
    _map[key] = entry;
    return entry.value;
  }

  void put(K key, V value) {
    final now = clock();
    if (_map.containsKey(key)) {
      // Overwrite: never evicts, just restamp and refresh recency.
      _map.remove(key);
    } else {
      _prune();
      if (_map.length >= capacity) {
        _map.remove(_map.keys.first);
      }
    }
    _map[key] = _Entry(value, now);
  }

  bool containsKey(K key) {
    final entry = _map[key];
    if (entry == null) return false;
    if (_expired(entry)) {
      _map.remove(key);
      return false;
    }
    return true;
  }

  void remove(K key) {
    _map.remove(key);
  }

  int get length {
    _prune();
    return _map.length;
  }

  List<K> get keys {
    _prune();
    return List.of(_map.keys);
  }
}
