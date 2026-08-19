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
  check('59s', humanize(const Duration(seconds: 59)), '59 seconds');
  check('60s', humanize(const Duration(seconds: 60)), '1 minute');
  check('61s', humanize(const Duration(seconds: 61)), '1 minute 1 second');
  check('3599s', humanize(const Duration(seconds: 3599)),
      '59 minutes 59 seconds');
  check('3600s', humanize(const Duration(seconds: 3600)), '1 hour');
  check('86399s', humanize(const Duration(seconds: 86399)),
      '23 hours 59 minutes');
  check('86400s', humanize(const Duration(seconds: 86400)), '1 day');
  check('1d1h1m1s', humanize(const Duration(seconds: 90061)), '1 day 1 hour');
  check('ms truncation', humanize(const Duration(milliseconds: 1999)),
      '1 second');
  check('neg sub-second', humanize(const Duration(milliseconds: -400)),
      '0 seconds');
  check('neg one second', humanize(const Duration(seconds: -1)),
      'minus 1 second');
  check('neg day', humanize(const Duration(hours: -25)), 'minus 1 day 1 hour');
  if (failures > 0) exit(1);
  print('edge ok');
}
