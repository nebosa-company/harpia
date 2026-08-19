import 'dart:io';

import '../lib/expr_eval.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected $expected, got $actual');
    failures++;
  }
}

void main() {
  check('precedence', evaluate('2+3*4'), 14);
  check('grouping', evaluate('(2+3)*4'), 20);
  check('left assoc minus', evaluate('10-4-3'), 3);
  check('left assoc div', evaluate('100/10/2'), 5.0);
  check('mul before pow? no', evaluate('2*3^2'), 18);
  check('pow right assoc', evaluate('2^3^2'), 512);
  check('unary vs pow', evaluate('-2^2'), -4);
  check('pow negative exponent', evaluate('2^-1'), 0.5);
  check('division is double', evaluate('10/4'), 2.5);
  check('int division result type', evaluate('6/3') is double, true);
  check('int stays int', evaluate('2+3') is int, true);
  check('modulo', evaluate('7%4'), 3);
  check('dart modulo sign', evaluate('(0-7)%4'), 1);
  check('unary minus', evaluate('-5+8'), 3);
  check('double unary', evaluate('- -5'), 5);
  check('parenthesized unary', evaluate('-(2+3)'), -5);
  check('decimals', evaluate('3.5*2'), 7.0);
  check('mixed', evaluate('1 + 2 * 3 - 4 / 8'), 6.5);
  check('whitespace', evaluate('  2 +\t3\n* 4 '), 14);

  check('variables', evaluate('x*x+y', variables: {'x': 3, 'y': 1}), 10);
  check('variable only', evaluate('speed', variables: {'speed': 88}), 88);
  check('underscore names',
      evaluate('_a1 * 2', variables: {'_a1': 5}), 10);

  check('min max', evaluate('min(3, max(1, 2))'), 2);
  check('abs', evaluate('abs(0-7)'), 7);
  check('abs negative literal', evaluate('abs(-7)'), 7);
  check('sqrt', evaluate('sqrt(9)'), 3.0);
  check('sqrt is double', evaluate('sqrt(4)') is double, true);
  check('call in expression', evaluate('2*min(4, 3)+1'), 7);
  check('nested calls', evaluate('max(min(10, 20), abs(-5))'), 10);
  check('function arg full expr', evaluate('min(2+3, 2^3)'), 5);

  check('pow of ints is int', evaluate('2^10'), 1024);
  check('pow keeps int type', evaluate('2^10') is int, true);
  if (failures > 0) exit(1);
  print('core ok');
}
