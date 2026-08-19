import 'dart:io';

import '../lib/csv_codec.dart';

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
  expectThrows<FormatException>(
      'unterminated quote', () => parseCsv('"abc'));
  expectThrows<FormatException>(
      'unterminated with escape', () => parseCsv('"a""'));
  expectThrows<FormatException>(
      'junk after close', () => parseCsv('"a"x,b'));
  expectThrows<FormatException>(
      'quote after close', () => parseCsv('"a" "b"'));
  expectThrows<FormatException>(
      'quote in unquoted', () => parseCsv('ab"c'));
  expectThrows<FormatException>(
      'late quote start', () => parseCsv('a,b"c"'));
  expectThrows<FormatException>('bare cr', () => parseCsv('a\rb'));
  expectThrows<FormatException>('cr at end', () => parseCsv('a\r'));

  // Quoted field directly containing doubled quotes at the edge.
  check('edge doubled quotes', parseCsv('"a"""'), [
    ['a"'],
  ]);
  check('only doubled quotes', parseCsv('""""'), [
    ['"'],
  ]);

  // Round trips.
  final gnarly = [
    ['plain', 'with,comma', 'with"quote'],
    ['multi\nline', 'crlf\r\nline', ''],
    ['', 'trailing'],
  ];
  check('gnarly round trip', parseCsv(encodeCsv(gnarly)), gnarly);

  final unicode = [
    ['café', 'naïve, oui'],
  ];
  check('unicode round trip', parseCsv(encodeCsv(unicode)), unicode);

  check('encode crlf field', encodeCsv([
    ['a\r\nb'],
  ]), '"a\r\nb"');
  check('single empty field rows mid-list', encodeCsv([
    [''],
    ['x'],
  ]), '\r\nx');
  check('parse of that', parseCsv('\r\nx'), [
    [''],
    ['x'],
  ]);
  if (failures > 0) exit(1);
  print('edge ok');
}
