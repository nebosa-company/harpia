import 'dart:io';

import '../lib/matrix_rotate.dart';

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
  check('empty', rotateClockwise(<List<int>>[]), <List<int>>[]);
  check('empty rows', rotateClockwise([<int>[], <int>[]]), <List<int>>[]);
  check('ccw empty rows', rotateCounterClockwise([<int>[]]), <List<int>>[]);
  expectThrows<ArgumentError>(
      'ragged cw', () => rotateClockwise([[1, 2], [3]]));
  expectThrows<ArgumentError>(
      'ragged ccw', () => rotateCounterClockwise([[1], [2, 3]]));

  // Four clockwise turns restore the original.
  final m = [[1, 2, 3], [4, 5, 6]];
  var r = m;
  for (var i = 0; i < 4; i++) {
    r = rotateClockwise(r);
  }
  check('four turns', r, m);

  // cw then ccw restores the original.
  check('inverse', rotateCounterClockwise(rotateClockwise(m)), m);

  // Input untouched, result rows fresh.
  final src = [[1, 2], [3, 4]];
  final out = rotateClockwise(src);
  out[0][0] = 99;
  out[1] = [7, 8];
  check('input intact', src, [[1, 2], [3, 4]]);
  if (failures > 0) exit(1);
  print('edge ok');
}
