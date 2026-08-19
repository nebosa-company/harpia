import 'dart:async';
import 'dart:io';

import '../lib/stream_timing.dart';

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

Future<void> pump() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> main() async {
  // FakeScheduler ordering and cancellation.
  {
    final sched = FakeScheduler();
    check('starts at zero', sched.now, 0);
    final calls = <String>[];
    sched.schedule(50, () => calls.add('b'));
    sched.schedule(10, () => calls.add('a'));
    sched.schedule(50, () => calls.add('c')); // same deadline as b, later seq
    sched.advance(50);
    check('deadline then seq order', calls, ['a', 'b', 'c']);
    check('now advanced', sched.now, 50);

    // Nested scheduling inside a running callback.
    sched.schedule(10, () {
      calls.add('x');
      sched.schedule(5, () => calls.add('y'));
    });
    sched.advance(20);
    check('nested fires in window', calls, ['a', 'b', 'c', 'x', 'y']);
    check('now at target', sched.now, 70);

    // now during a callback equals its deadline.
    var seen = -1;
    sched.schedule(30, () => seen = sched.now);
    sched.advance(100);
    check('now inside callback', seen, 100);
    check('now after advance', sched.now, 170);

    // Cancel prevents firing; double cancel is a no-op.
    var fired = false;
    final cancel = sched.schedule(5, () => fired = true);
    cancel();
    cancel();
    sched.advance(10);
    check('cancelled never fires', fired, false);

    // Deadline beyond the window stays queued.
    var late = false;
    sched.schedule(100, () => late = true);
    sched.advance(99);
    check('not yet', late, false);
    sched.advance(1);
    check('fires at boundary', late, true);

    expectThrows<ArgumentError>('negative advance', () => sched.advance(-1));
    expectThrows<ArgumentError>(
        'negative delay', () => sched.schedule(-5, () {}));
  }

  // Throttle: leading edge, quiet window, reopen at boundary.
  {
    final src = StreamController<int>();
    final sched = FakeScheduler();
    final out = <int>[];
    var done = false;
    throttle(src.stream, 100, sched).listen(out.add, onDone: () => done = true);
    await pump();

    src.add(1);
    await pump();
    check('leading emit', out, [1]);
    src.add(2);
    await pump();
    sched.advance(50);
    src.add(3);
    await pump();
    check('window drops', out, [1]);
    sched.advance(50); // window elapsed at t=100
    src.add(4);
    await pump();
    check('reopen at boundary', out, [1, 4]);
    sched.advance(100);
    await pump();
    src.add(5);
    await pump();
    check('later event emits', out, [1, 4, 5]);

    // Close mid-window: done fires immediately, no trailing event.
    src.add(6);
    await pump();
    await src.close();
    await pump();
    check('no trailing', out, [1, 4, 5]);
    check('done immediately', done, true);
  }

  // Throttle: errors forwarded even inside the quiet window.
  {
    final src = StreamController<int>();
    final sched = FakeScheduler();
    final out = <int>[];
    final errors = <Object>[];
    throttle(src.stream, 100, sched).listen(out.add, onError: errors.add);
    await pump();
    src.add(1);
    await pump();
    src.addError(StateError('mid-window'));
    await pump();
    check('throttle error', errors.length, 1);
    check('throttle out', out, [1]);
    await src.close();
    await pump();
  }

  // Debounce subscribes lazily and cancels upstream on cancel.
  {
    var listened = false;
    var cancelled = false;
    final src = StreamController<int>(
        onListen: () => listened = true, onCancel: () => cancelled = true);
    final sched = FakeScheduler();
    final stream = debounce(src.stream, 10, sched);
    await pump();
    check('lazy subscribe', listened, false);
    final sub = stream.listen((_) {});
    await pump();
    check('subscribed on listen', listened, true);
    await sub.cancel();
    await pump();
    check('upstream cancelled', cancelled, true);
  }
  if (failures > 0) exit(1);
  print('edge ok');
}
