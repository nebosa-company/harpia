import 'dart:io';

import '../lib/roster.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected <$expected>, got <$actual>');
    failures++;
  }
}

void main() {
  check('bare member', displayLine(Member('Solo Dev')), 'Solo Dev (no email)');
  check('empty roster', rosterReport([]), '');
  check('single line no newline', rosterReport([Member('Only One')]),
      'Only One (no email)');
  final mixed = rosterReport([
    Member('A B', nickname: 'ab'),
    Member('C D', email: 'cd@x.io'),
    Member('E F'),
  ]);
  check('mixed nulls', mixed, 'ab (A B) (no email)\nC D <cd@x.io>\nE F (no email)');
  // Constructor shape must be unchanged: positional name, named optionals.
  final m = Member('N', nickname: 'n', email: 'e@x');
  check('fields kept', '${m.name}|${m.nickname}|${m.email}', 'N|n|e@x');
  if (failures > 0) exit(1);
  print('edge ok');
}
