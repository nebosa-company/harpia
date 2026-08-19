import 'dart:io';

import '../lib/bracket_matcher.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected $expected, got $actual');
    failures++;
  }
}

void main() {
  check('empty', isBalanced(''), true);
  check('pair', isBalanced('()'), true);
  check('mixed', isBalanced('([]{})'), true);
  check('wrong pair', isBalanced('(]'), false);
  check('interleaved', isBalanced('([)]'), false);
  check('unclosed', isBalanced('((('), false);
  check('text around', isBalanced('a(b)c'), true);
  check('closer first', isBalanced(')('), false);
  check('no brackets', isBalanced('plain text!'), true);
  check('nested deep', isBalanced('{[()()]}'), true);
  check('extra closer', isBalanced('()]'), false);
  check('sequential', isBalanced('()[]{}'), true);
  if (failures > 0) exit(1);
  print('core ok');
}
