/// Debounce and throttle stream operators driven by an injectable scheduler.

import 'dart:async';

typedef CancelTimer = void Function();

/// Source of virtual time; all operator timing goes through this.
abstract class Scheduler {
  int get now;
  CancelTimer schedule(int delayMs, void Function() callback);
}

class _Scheduled {
  final int deadline;
  final int seq;
  final void Function() callback;
  bool cancelled = false;

  _Scheduled(this.deadline, this.seq, this.callback);
}

/// Manual scheduler for deterministic control of time.
class FakeScheduler implements Scheduler {
  int _now = 0;
  int _seq = 0;
  final List<_Scheduled> _queue = [];

  @override
  int get now => _now;

  @override
  CancelTimer schedule(int delayMs, void Function() callback) {
    if (delayMs < 0) throw ArgumentError('delayMs must be >= 0');
    final item = _Scheduled(_now + delayMs, _seq++, callback);
    _queue.add(item);
    return () => item.cancelled = true;
  }

  void advance(int ms) {
    if (ms < 0) throw ArgumentError('ms must be >= 0');
    final target = _now + ms;
    while (true) {
      _Scheduled? next;
      for (final item in _queue) {
        if (item.cancelled || item.deadline > target) continue;
        if (next == null ||
            item.deadline < next.deadline ||
            (item.deadline == next.deadline && item.seq < next.seq)) {
          next = item;
        }
      }
      if (next == null) break;
      _queue.remove(next);
      _now = next.deadline;
      next.callback();
    }
    _now = target;
    _queue.removeWhere((item) => item.cancelled);
  }
}

/// Trailing debounce; see the brief for exact semantics.
Stream<T> debounce<T>(Stream<T> source, int windowMs, Scheduler scheduler) {
  final controller = StreamController<T>();
  StreamSubscription<T>? subscription;
  CancelTimer? pending;
  T? latest;
  var hasLatest = false;

  void flush() {
    if (!hasLatest) return;
    final value = latest as T;
    hasLatest = false;
    pending = null;
    controller.add(value);
  }

  controller.onListen = () {
    subscription = source.listen((event) {
      pending?.call();
      latest = event;
      hasLatest = true;
      pending = scheduler.schedule(windowMs, flush);
    }, onError: controller.addError, onDone: () {
      pending?.call();
      flush();
      controller.close();
    });
  };
  controller.onCancel = () => subscription?.cancel();
  return controller.stream;
}

/// Leading throttle; see the brief for exact semantics.
Stream<T> throttle<T>(Stream<T> source, int windowMs, Scheduler scheduler) {
  final controller = StreamController<T>();
  StreamSubscription<T>? subscription;
  var open = true;

  controller.onListen = () {
    subscription = source.listen((event) {
      if (!open) return;
      open = false;
      controller.add(event);
      scheduler.schedule(windowMs, () => open = true);
    }, onError: controller.addError, onDone: controller.close);
  };
  controller.onCancel = () => subscription?.cancel();
  return controller.stream;
}
