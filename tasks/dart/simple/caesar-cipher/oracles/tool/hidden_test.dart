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
  check('basic', encode('abc', 3), 'def');
  check('wrap', encode('xyz', 3), 'abc');
  check('negative', encode('abc', -1), 'zab');
  check('mixed case', encode('Hello, World!', 5), 'Mjqqt, Btwqi!');
  check('decode basic', decode('def', 3), 'abc');
  check('decode wrap', decode('abc', 3), 'xyz');
  check('zero shift', encode('Keep Me', 0), 'Keep Me');
  check('full circle', encode('Round Trip', 26), 'Round Trip');
  check('digits kept', encode('a1b2c3', 1), 'b1c2d3');
  check('round trip', decode(encode('The Quick Brown Fox!', 17), 17),
      'The Quick Brown Fox!');
  if (failures > 0) exit(1);
  print('core ok');
}
