/// Fixed-size isolate worker pool.

import 'dart:async';

/// Error surfaced when a pooled task throws on its worker isolate.
class ComputeError implements Exception {
  final String message;

  ComputeError(this.message);

  @override
  String toString() => 'ComputeError: $message';
}

/// A pool of long-lived worker isolates executing submitted tasks.
class ComputePool {
  ComputePool._();

  static Future<ComputePool> start(int size) => throw UnimplementedError();

  int get size => throw UnimplementedError();

  Future<R> run<Q, R>(FutureOr<R> Function(Q) task, Q arg) =>
      throw UnimplementedError();

  Future<void> close() => throw UnimplementedError();
}
