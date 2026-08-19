import 'dart:io';

import '../lib/ttl_cache.dart';

int failures = 0;

bool deepEq(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEq(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

void check(String label, Object? actual, Object? expected) {
  if (!deepEq(actual, expected)) {
    print('FAIL $label: expected $expected, got $actual');
    failures++;
  }
}

void expectThrows<T>(String label, void Function() fn) {
  try {
    fn();
    print('FAIL $label: expected $T, nothing thrown');
    failures++;
  } on Object catch (e) {
    if (e is! T) {
      print('FAIL $label: expected $T, got ${e.runtimeType}');
      failures++;
    }
  }
}

void main() {
  var t = 0;
  TtlCache<String, int> fresh(int capacity, int ttl) =>
      TtlCache(capacity: capacity, ttlMs: ttl, clock: () => t);

  expectThrows<ArgumentError>(
      'zero capacity', () => fresh(0, 100));
  expectThrows<ArgumentError>(
      'zero ttl', () => fresh(2, 0));

  // Overwriting at capacity must not evict anything.
  t = 0;
  final ow = fresh(2, 1000);
  ow.put('a', 1);
  ow.put('b', 2);
  ow.put('b', 9); // overwrite while full
  check('a untouched by overwrite', ow.get('a'), 1);
  check('overwrite value', ow.get('b'), 9);
  check('overwrite keeps size', ow.length, 2);

  // Overwrite refreshes recency: after updating a, b is the LRU.
  t = 0;
  final owLru = fresh(2, 1000);
  owLru.put('a', 1);
  owLru.put('b', 2);
  owLru.put('a', 3); // a becomes most recently used
  owLru.put('c', 4); // evicts b
  check('b was lru', owLru.get('b'), null);
  check('a refreshed by overwrite', owLru.get('a'), 3);
  check('c inserted', owLru.get('c'), 4);

  // Expired entries are pruned before a live one is evicted.
  t = 0;
  final pruneFirst = fresh(2, 100);
  pruneFirst.put('old', 1);
  t = 10;
  pruneFirst.put('young', 2);
  t = 100; // old expired, young alive
  pruneFirst.put('new', 3);
  check('expired pruned first', pruneFirst.get('young'), 2);
  check('new present', pruneFirst.get('new'), 3);
  check('old gone', pruneFirst.containsKey('old'), false);
  check('size after prune', pruneFirst.length, 2);

  // keys is ordered least recently used -> most recently used.
  t = 0;
  final order = fresh(3, 1000);
  order.put('a', 1);
  order.put('b', 2);
  order.put('c', 3);
  check('insert order', order.keys, ['a', 'b', 'c']);
  order.get('a');
  check('read reorders', order.keys, ['b', 'c', 'a']);
  order.put('b', 9);
  check('overwrite reorders', order.keys, ['c', 'a', 'b']);

  // containsKey does not change recency.
  t = 0;
  final peek = fresh(2, 1000);
  peek.put('a', 1);
  peek.put('b', 2);
  peek.containsKey('a'); // must NOT refresh a
  peek.put('c', 3); // evicts a
  check('containsKey not a touch', peek.get('a'), null);
  check('b kept', peek.get('b'), 2);

  // Capacity one churn.
  t = 0;
  final one = fresh(1, 1000);
  one.put('a', 1);
  one.put('b', 2);
  check('single slot', one.keys, ['b']);
  check('a evicted', one.get('a'), null);
  if (failures > 0) exit(1);
  print('edge ok');
}
