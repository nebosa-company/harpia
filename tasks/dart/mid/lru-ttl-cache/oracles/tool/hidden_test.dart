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

void main() {
  var t = 0;
  TtlCache<String, int> fresh(int capacity, int ttl) =>
      TtlCache(capacity: capacity, ttlMs: ttl, clock: () => t);

  // Basics.
  t = 0;
  final c = fresh(3, 1000);
  c.put('a', 1);
  check('get hit', c.get('a'), 1);
  check('get miss', c.get('zz'), null);
  check('contains', c.containsKey('a'), true);
  check('length', c.length, 1);
  c.remove('a');
  check('removed', c.get('a'), null);

  // Reading refreshes recency: the read key must survive eviction.
  t = 0;
  final lru = fresh(2, 1000);
  lru.put('a', 1);
  lru.put('b', 2);
  check('read a', lru.get('a'), 1);
  lru.put('c', 3); // b is now least recently used
  check('b evicted', lru.get('b'), null);
  check('a survived', lru.get('a'), 1);
  check('c present', lru.get('c'), 3);

  // Repeated reads keep an entry hot through several evictions.
  t = 0;
  final hot = fresh(2, 100000);
  hot.put('hot', 0);
  for (var i = 0; i < 5; i++) {
    hot.put('cold$i', i);
    check('hot stays $i', hot.get('hot'), 0);
  }
  check('hot still there', hot.containsKey('hot'), true);

  // TTL: entries die at exactly ttlMs after their last write.
  t = 0;
  final ttl = fresh(3, 100);
  ttl.put('x', 7);
  t = 99;
  check('alive at 99', ttl.get('x'), 7);
  t = 100;
  check('dead at 100', ttl.get('x'), null);
  check('gone after expiry', ttl.containsKey('x'), false);

  // Reads do not extend life.
  t = 0;
  final noExtend = fresh(3, 100);
  noExtend.put('y', 1);
  t = 50;
  check('mid-life read', noExtend.get('y'), 1);
  t = 100;
  check('read did not extend', noExtend.get('y'), null);

  // Overwrite restamps.
  t = 0;
  final restamp = fresh(3, 100);
  restamp.put('z', 1);
  t = 80;
  restamp.put('z', 2);
  t = 179;
  check('restamped alive', restamp.get('z'), 2);
  t = 180;
  check('restamped dies', restamp.get('z'), null);

  // length and keys prune expired entries.
  t = 0;
  final pruning = fresh(5, 100);
  pruning.put('a', 1);
  t = 60;
  pruning.put('b', 2);
  t = 100; // a expired, b alive
  check('pruned length', pruning.length, 1);
  check('pruned keys', pruning.keys, ['b']);
  if (failures > 0) exit(1);
  print('core ok');
}
