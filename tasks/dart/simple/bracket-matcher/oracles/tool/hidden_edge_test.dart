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
  check('balanced null', firstError('()[]'), null);
  check('mismatch idx', firstError('(]'), 1);
  check('interleave idx', firstError('([)]'), 2);
  check('all open', firstError('((('), 0);
  check('late open', firstError('()('), 2);
  check('lone closer', firstError(')'), 0);
  check('text offset', firstError('ab)('), 2);
  check('code sample', isBalanced('if (a[0] == b) { return; }'), true);
  check('mid mismatch', firstError('f(x[1)]'), 5);
  final deep = '(' * 2000 + ')' * 2000;
  check('deep balanced', isBalanced(deep), true);
  check('deep unclosed', firstError('(' * 5 + ')' * 4), 0);
  check('empty null', firstError(''), null);
  check('agree', isBalanced('([)]') == (firstError('([)]') == null), true);
  if (failures > 0) exit(1);
  print('edge ok');
}
