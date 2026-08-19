import 'dart:async';
import 'dart:io';

import '../lib/compute_pool.dart';

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

// Top-level task functions (sendable to isolates).
int square(int x) => x * x;

String greet(String name) => 'hi $name';

Future<int> asyncDouble(int x) async => x * 2;

int _counter = 0;

int bump(int by) {
  _counter += by;
  return _counter;
}

int _hits = 0;

int hitAndCount(int ignored) {
  _hits++;
  return _hits;
}

Future<void> main() async {
  // Basic execution and generics.
  final pool = await ComputePool.start(2);
  check('size', pool.size, 2);
  check('square', await pool.run(square, 7), 49);
  check('string result', await pool.run(greet, 'bob'), 'hi bob');
  check('async task', await pool.run(asyncDouble, 21), 42);

  // More jobs than workers: all queue and all complete correctly.
  final futures = [for (var i = 0; i < 6; i++) pool.run(square, i)];
  check('queued batch', await Future.wait(futures), [0, 1, 4, 9, 16, 25]);
  await pool.close();

  // Workers are reused, and tasks never run on the main isolate.
  final single = await ComputePool.start(1);
  check('worker state persists', await single.run(bump, 5), 5);
  check('same worker again', await single.run(bump, 5), 10);
  check('main isolate untouched', _counter, 0);
  await single.close();

  // Reuse under load: 6 sequential jobs on 2 workers must revisit a worker.
  final duo = await ComputePool.start(2);
  final counts = <int>[];
  for (var i = 0; i < 6; i++) {
    counts.add(await duo.run(hitAndCount, 0));
  }
  var maxCount = 0;
  for (final c in counts) {
    if (c > maxCount) maxCount = c;
  }
  check('pigeonhole reuse', maxCount >= 3, true);
  check('fresh worker state', _hits, 0);
  await duo.close();
  if (failures > 0) exit(1);
  print('core ok');
}
