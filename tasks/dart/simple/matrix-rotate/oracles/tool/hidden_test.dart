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

void main() {
  check('cw 2x2', rotateClockwise([[1, 2], [3, 4]]), [[3, 1], [4, 2]]);
  check('ccw 2x2', rotateCounterClockwise([[1, 2], [3, 4]]), [[2, 4], [1, 3]]);
  check('cw 2x3', rotateClockwise([[1, 2, 3], [4, 5, 6]]),
      [[4, 1], [5, 2], [6, 3]]);
  check('ccw 2x3', rotateCounterClockwise([[1, 2, 3], [4, 5, 6]]),
      [[3, 6], [2, 5], [1, 4]]);
  check('cw 3x3', rotateClockwise([[1, 2, 3], [4, 5, 6], [7, 8, 9]]),
      [[7, 4, 1], [8, 5, 2], [9, 6, 3]]);
  check('cw 1x1', rotateClockwise([[42]]), [[42]]);
  check('cw strings', rotateClockwise([['a', 'b'], ['c', 'd']]),
      [['c', 'a'], ['d', 'b']]);
  check('single row', rotateClockwise([[1, 2, 3]]), [[1], [2], [3]]);
  check('single col', rotateClockwise([[1], [2], [3]]), [[3, 2, 1]]);
  if (failures > 0) exit(1);
  print('core ok');
}
