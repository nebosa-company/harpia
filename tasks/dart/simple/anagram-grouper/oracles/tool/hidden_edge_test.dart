import 'dart:io';

import '../lib/anagram_grouper.dart';

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
  check('empty string words', groupAnagrams(['', 'a', '']), [
    ['', ''],
    ['a'],
  ]);
  check('punctuation counts', groupAnagrams(['a-b', 'b-a', 'ab']), [
    ['a-b', 'b-a'],
    ['ab'],
  ]);
  check('digits count', groupAnagrams(['ab1', '1ba', 'ab2']), [
    ['ab1', '1ba'],
    ['ab2'],
  ]);
  check('length matters', groupAnagrams(['aab', 'ab', 'ba', 'aba']), [
    ['aab', 'aba'],
    ['ab', 'ba'],
  ]);
  check('order by first member',
      groupAnagrams(['zoo', 'cat', 'ooz', 'act', 'tac', 'oz']), [
    ['zoo', 'ooz'],
    ['cat', 'act', 'tac'],
    ['oz'],
  ]);
  check('casing preserved', groupAnagrams(['AbC', 'cAb', 'BCA']), [
    ['AbC', 'cAb', 'BCA'],
  ]);
  if (failures > 0) exit(1);
  print('edge ok');
}
