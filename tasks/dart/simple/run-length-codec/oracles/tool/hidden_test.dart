import 'dart:io';

import '../lib/run_length.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected <$expected>, got <$actual>');
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

void main() {
  check('encode basic', rleEncode('aaabccddd'), '3a1b2c3d');
  check('encode single runs', rleEncode('abc'), '1a1b1c');
  check('encode case runs', rleEncode('aA'), '1a1A');
  check('encode empty', rleEncode(''), '');
  check('encode long run', rleEncode('a' * 12), '12a');
  check('decode basic', rleDecode('3a1b2c3d'), 'aaabccddd');
  check('decode empty', rleDecode(''), '');
  check('decode long', rleDecode('12a'), 'a' * 12);
  check('round trip', rleDecode(rleEncode('WwWwZZZZzzzQ')), 'WwWwZZZZzzzQ');
  expectThrows<ArgumentError>('encode digit', () => rleEncode('ab1'));
  expectThrows<ArgumentError>('encode space', () => rleEncode('a b'));
  if (failures > 0) exit(1);
  print('core ok');
}
