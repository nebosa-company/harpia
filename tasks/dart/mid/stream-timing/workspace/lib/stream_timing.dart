/// Debounce and throttle stream operators driven by an injectable scheduler.

import 'dart:async';

typedef CancelTimer = void Function();

/// Source of virtual time; all operator timing goes through this.
abstract class Scheduler {
  int get now;
  CancelTimer schedule(int delayMs, void Function() callback);
}

/// Manual scheduler for deterministic control of time.
class FakeScheduler implements Scheduler {
  @override
  int get now => throw UnimplementedError();

  @override
  CancelTimer schedule(int delayMs, void Function() callback) =>
      throw UnimplementedError();

  void advance(int ms) => throw UnimplementedError();
}

/// Trailing debounce; see the brief for exact semantics.
Stream<T> debounce<T>(Stream<T> source, int windowMs, Scheduler scheduler) =>
    throw UnimplementedError();

/// Leading throttle; see the brief for exact semantics.
Stream<T> throttle<T>(Stream<T> source, int windowMs, Scheduler scheduler) =>
    throw UnimplementedError();
