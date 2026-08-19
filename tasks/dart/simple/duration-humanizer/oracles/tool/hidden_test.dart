import 'dart:io';

import '../lib/duration_humanizer.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected <$expected>, got <$actual>');
    failures++;
  }
}

void main() {
  check('zero', humanize(Duration.zero), '0 seconds');
  check('sub-second', humanize(const Duration(milliseconds: 900)), '0 seconds');
  check('one second', humanize(const Duration(seconds: 1)), '1 second');
  check('seconds', humanize(const Duration(seconds: 45)), '45 seconds');
  check('min sec', humanize(const Duration(minutes: 2, seconds: 5)),
      '2 minutes 5 seconds');
  check('gap unit', humanize(const Duration(hours: 2, seconds: 5)),
      '2 hours 5 seconds');
  check('day rollup', humanize(const Duration(hours: 26)), '1 day 2 hours');
  check('days only', humanize(const Duration(days: 400)), '400 days');
  check('negative', humanize(const Duration(minutes: -90)),
      'minus 1 hour 30 minutes');
  check('two of four',
      humanize(const Duration(days: 2, hours: 3, minutes: 59, seconds: 59)),
      '2 days 3 hours');
  if (failures > 0) exit(1);
  print('core ok');
}
