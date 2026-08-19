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

void main() {
  check('basic', parseCsv('a,b,c\n1,2,3'), [
    ['a', 'b', 'c'],
    ['1', '2', '3'],
  ]);
  check('crlf', parseCsv('a,b\r\nc,d'), [
    ['a', 'b'],
    ['c', 'd'],
  ]);
  check('mixed newlines', parseCsv('a\r\nb\nc'), [
    ['a'],
    ['b'],
    ['c'],
  ]);
  check('trailing newline', parseCsv('a,b\n'), [
    ['a', 'b'],
  ]);
  check('trailing crlf', parseCsv('a,b\r\n'), [
    ['a', 'b'],
  ]);
  check('empty input', parseCsv(''), <List<String>>[]);
  check('empty fields', parseCsv('a,,b'), [
    ['a', '', 'b'],
  ]);
  check('trailing comma', parseCsv('a,'), [
    ['a', ''],
  ]);
  check('empty line mid-file', parseCsv('a\n\nb'), [
    ['a'],
    [''],
    ['b'],
  ]);
  check('quoted comma', parseCsv('"a,b",c'), [
    ['a,b', 'c'],
  ]);
  check('escaped quotes', parseCsv('"say ""hi""",x'), [
    ['say "hi"', 'x'],
  ]);
  check('newline in quotes', parseCsv('"l1\nl2",b'), [
    ['l1\nl2', 'b'],
  ]);
  check('crlf in quotes', parseCsv('"l1\r\nl2"'), [
    ['l1\r\nl2'],
  ]);
  check('quoted empty', parseCsv('""'), [
    [''],
  ]);

  check('encode simple', encodeCsv([
    ['a', 'b'],
    ['c', 'd'],
  ]), 'a,b\r\nc,d');
  check('encode empty list', encodeCsv([]), '');
  check('encode comma', encodeCsv([
    ['a,b', 'c'],
  ]), '"a,b",c');
  check('encode quote', encodeCsv([
    ['a"b', 'c'],
  ]), '"a""b",c');
  check('encode newline', encodeCsv([
    ['l1\nl2'],
  ]), '"l1\nl2"');
  check('encode plain untouched', encodeCsv([
    ['hello world', 'x.y'],
  ]), 'hello world,x.y');
  if (failures > 0) exit(1);
  print('core ok');
}
