import 'dart:io';

import '../lib/team_service.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected <$expected>, got <$actual>');
    failures++;
  }
}

Future<void> main() async {
  // The refactor is real: no Completer, no scheduleMicrotask, no callback
  // parameters; async/await instead.
  final source = File('lib/team_service.dart').readAsStringSync();
  check('no Completer', source.contains('Completer'), false);
  check('no scheduleMicrotask', source.contains('scheduleMicrotask'), false);
  check('uses await', source.contains('await'), true);
  check('uses async', source.contains('async'), true);

  // Shape holds under concurrent use.
  final service = TeamService({
    'a': {'name': 'A', 'role': 'r1'},
    'b': {'name': 'B', 'role': 'r2'},
  }, {
    'x': {
      'name': 'X',
      'members': ['a', 'b'],
    },
    'y': {
      'name': 'Y',
      'members': ['b'],
    },
  });
  final reports = await Future.wait([
    service.teamReport('x'),
    service.teamReport('y'),
    service.teamReport('x'),
  ]);
  check('concurrent 0', reports[0], 'X:\n- A (r1)\n- B (r2)');
  check('concurrent 1', reports[1], 'Y:\n- B (r2)');
  check('concurrent 2', reports[2], 'X:\n- A (r1)\n- B (r2)');

  // Future is asynchronous: the report is not computed synchronously.
  var settled = false;
  final pending = service.teamReport('x').then((r) {
    settled = true;
    return r;
  });
  check('not synchronous', settled, false);
  check('then resolves', await pending, 'X:\n- A (r1)\n- B (r2)');
  if (failures > 0) exit(1);
  print('edge ok');
}
