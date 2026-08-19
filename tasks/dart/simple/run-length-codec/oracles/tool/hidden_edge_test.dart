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
  expectThrows<FormatException>('bare letter', () => rleDecode('a'));
  expectThrows<FormatException>('letter no count', () => rleDecode('3ab'));
  expectThrows<FormatException>('trailing digits', () => rleDecode('3'));
  expectThrows<FormatException>('digits at end', () => rleDecode('2a10'));
  expectThrows<FormatException>('zero count', () => rleDecode('3a0b'));
  expectThrows<FormatException>('punctuation', () => rleDecode('3a,2b'));
  expectThrows<ArgumentError>('encode punct', () => rleEncode('a-b'));
  check('multi digit counts', rleDecode('10a2B'), '${'a' * 10}BB');
  check('encode 100 run', rleEncode('${'x' * 100}y'), '100x1y');
  final tricky = 'aAaAbBBbb';
  check('tricky round trip', rleDecode(rleEncode(tricky)), tricky);
  check('boundary z Z', rleEncode('zzZZ'), '2z2Z');
  if (failures > 0) exit(1);
  print('edge ok');
}
