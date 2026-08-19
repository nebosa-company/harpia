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
  check('classic', groupAnagrams(['eat', 'Tea', 'tan', 'ate', 'nat', 'bat']), [
    ['eat', 'Tea', 'ate'],
    ['tan', 'nat'],
    ['bat'],
  ]);
  check('case insensitive', groupAnagrams(['Listen', 'Silent', 'enlist']), [
    ['Listen', 'Silent', 'enlist'],
  ]);
  check('duplicates', groupAnagrams(['a', 'a']), [
    ['a', 'a'],
  ]);
  check('empty input', groupAnagrams([]), <List<String>>[]);
  check('no anagrams', groupAnagrams(['one', 'two', 'three']), [
    ['one'],
    ['two'],
    ['three'],
  ]);
  if (failures > 0) exit(1);
  print('core ok');
}
