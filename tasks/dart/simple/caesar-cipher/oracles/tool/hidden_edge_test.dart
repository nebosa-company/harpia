import 'dart:io';

import '../lib/caesar_cipher.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected <$expected>, got <$actual>');
    failures++;
  }
}

void main() {
  check('empty', encode('', 13), '');
  check('big shift', encode('abc', 79), 'bcd');
  check('big negative', encode('abc', -27), 'zab');
  check('case wrap', encode('Zz', 1), 'Aa');
  check('non-ascii kept', encode('caf\u00e9 na\u00efve', 2), 'ech\u00e9 pc\u00efxg');
  check('punct only', encode('.,;!?', 9), '.,;!?');
  check('rot13 symmetry', encode('Why did the chicken', 13),
      decode('Why did the chicken', 13));
  check('huge shift round trip', decode(encode('EdgeCase', 1000003), 1000003),
      'EdgeCase');
  check('neg round trip', decode(encode('Zebra zone', -5), -5), 'Zebra zone');
  if (failures > 0) exit(1);
  print('edge ok');
}
