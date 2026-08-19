import 'dart:async';
import 'dart:io';

import '../lib/compute_pool.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected $expected, got $actual');
    failures++;
  }
}

// Top-level task functions (sendable to isolates).
int square(int x) => x * x;

int boom(int ignored) => throw StateError('boom');

Future<int> asyncBoom(int ignored) async => throw ArgumentError('later');

int spin(int rounds) {
  var acc = 0;
  for (var i = 0; i < rounds; i++) {
    acc = (acc + i) & 0x7fffffff;
  }
  return acc;
}

Future<void> main() async {
  // start(0) rejected synchronously.
  var startThrew = false;
  try {
    ComputePool.start(0);
  } on ArgumentError {
    startThrew = true;
  }
  check('start zero', startThrew, true);

  final pool = await ComputePool.start(2);

  // Sync throw becomes a ComputeError with the original toString.
  Object? error;
  try {
    await pool.run(boom, 0);
  } catch (e) {
    error = e;
  }
  check('compute error type', error is ComputeError, true);
  check('compute error message', (error as ComputeError).message,
      'Bad state: boom');
  check('compute error toString', error.toString(),
      'ComputeError: Bad state: boom');

  // Async error propagates the same way.
  Object? asyncError;
  try {
    await pool.run(asyncBoom, 0);
  } catch (e) {
    asyncError = e;
  }
  check('async compute error', asyncError is ComputeError, true);
  check('async message', (asyncError as ComputeError).message,
      'Invalid argument(s): later');

  // Pool still works after task failures.
  check('healthy after error', await pool.run(square, 6), 36);

  // close waits for the running job and for queued jobs.
  final slow = pool.run(spin, 5000000);
  final queuedA = pool.run(square, 3);
  final queuedB = pool.run(square, 4);
  var slowDone = false;
  var queuedDone = 0;
  unawaited(slow.then((_) => slowDone = true));
  unawaited(queuedA.then((v) {
    if (v == 9) queuedDone++;
  }));
  unawaited(queuedB.then((v) {
    if (v == 16) queuedDone++;
  }));
  final closeFuture = pool.close();

  // run after close throws StateError synchronously.
  var runThrew = false;
  try {
    pool.run(square, 1);
  } on StateError {
    runThrew = true;
  }
  check('run after close', runThrew, true);

  await closeFuture;
  await Future<void>.delayed(Duration.zero);
  check('close waited for running job', slowDone, true);
  check('close waited for queued jobs', queuedDone, 2);

  // close is idempotent and returns the same Future.
  final again = pool.close();
  check('same close future', identical(again, closeFuture), true);
  await again;
  if (failures > 0) exit(1);
  print('edge ok');
}
