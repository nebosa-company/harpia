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
  check('full member',
      displayLine(Member('Ada Lovelace', nickname: 'Ada', email: 'ada@example.com')),
      'Ada (Ada Lovelace) <ada@example.com>');
  check('no nickname',
      displayLine(Member('Charles Babbage', email: 'cb@example.com')),
      'Charles Babbage <cb@example.com>');
  check('no email',
      displayLine(Member('Grace Hopper', nickname: 'Amazing Grace')),
      'Amazing Grace (Grace Hopper) (no email)');
  final report = rosterReport([
    Member('Ada Lovelace', nickname: 'Ada', email: 'ada@example.com'),
    Member('Charles Babbage', email: 'cb@example.com'),
    Member('Grace Hopper', nickname: 'Amazing Grace'),
  ]);
  check(
      'report',
      report,
      'Ada (Ada Lovelace) <ada@example.com>\n'
      'Charles Babbage <cb@example.com>\n'
      'Amazing Grace (Grace Hopper) (no email)');
  if (failures > 0) exit(1);
  print('core ok');
}
