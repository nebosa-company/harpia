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

Future<void> pump() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> main() async {
  // Debounce: quiet window emits the latest event.
  {
    final src = StreamController<int>();
    final sched = FakeScheduler();
    final out = <int>[];
    var done = false;
    debounce(src.stream, 100, sched).listen(out.add, onDone: () => done = true);
    await pump();

    src.add(1);
    await pump();
    sched.advance(99);
    await pump();
    check('nothing before window', out, <int>[]);

    src.add(2); // restarts the countdown at t=99
    await pump();
    sched.advance(1); // t=100: original deadline, must NOT fire
    await pump();
    check('restart on new event', out, <int>[]);

    sched.advance(99); // t=199: new deadline
    await pump();
    check('latest emitted', out, [2]);

    src.add(3);
    await pump();
    sched.advance(100);
    await pump();
    check('second emission', out, [2, 3]);

    // Burst: only the last survives.
    src.add(4);
    await pump();
    src.add(5);
    await pump();
    src.add(6);
    await pump();
    sched.advance(100);
    await pump();
    check('burst keeps last', out, [2, 3, 6]);

    check('not done yet', done, false);
    await src.close();
    await pump();
    check('done after close', done, true);
    check('no extra events', out, [2, 3, 6]);
  }

  // Debounce: closing with a pending event flushes it.
  {
    final src = StreamController<String>();
    final sched = FakeScheduler();
    final out = <String>[];
    var done = false;
    debounce(src.stream, 50, sched)
        .listen(out.add, onDone: () => done = true);
    await pump();
    src.add('pending');
    await pump();
    await src.close();
    await pump();
    check('flush on close', out, ['pending']);
    check('closed', done, true);
  }

  // Debounce: errors forwarded immediately.
  {
    final src = StreamController<int>();
    final sched = FakeScheduler();
    final out = <int>[];
    final errors = <Object>[];
    debounce(src.stream, 100, sched)
        .listen(out.add, onError: errors.add);
    await pump();
    src.add(7);
    await pump();
    src.addError(StateError('boom'));
    await pump();
    check('error forwarded', errors.length, 1);
    check('error before flush', out, <int>[]);
    sched.advance(100);
    await pump();
    check('pending survives error', out, [7]);
    await src.close();
    await pump();
  }
  if (failures > 0) exit(1);
  print('core ok');
}
