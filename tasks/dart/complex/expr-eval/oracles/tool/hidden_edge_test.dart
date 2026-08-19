import 'dart:io';

import '../lib/expr_eval.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
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
  // Syntax errors.
  expectThrows<FormatException>('empty', () => evaluate(''));
  expectThrows<FormatException>('spaces only', () => evaluate('   '));
  expectThrows<FormatException>('dangling op', () => evaluate('2 +'));
  expectThrows<FormatException>('leading op', () => evaluate('*3'));
  expectThrows<FormatException>('unclosed paren', () => evaluate('(2'));
  expectThrows<FormatException>('extra close', () => evaluate('2)'));
  expectThrows<FormatException>('adjacent numbers', () => evaluate('2 3'));
  expectThrows<FormatException>('bad char', () => evaluate('2 @ 3'));
  expectThrows<FormatException>('bare dot', () => evaluate('.5'));
  expectThrows<FormatException>('trailing dot', () => evaluate('2.'));
  expectThrows<FormatException>('double dot', () => evaluate('2..5'));
  expectThrows<FormatException>('empty parens', () => evaluate('()'));
  expectThrows<FormatException>('empty args', () => evaluate('min()'));
  expectThrows<FormatException>('trailing comma', () => evaluate('min(1,)'));
  expectThrows<FormatException>('stray comma', () => evaluate('1, 2'));
  expectThrows<FormatException>('unclosed call', () => evaluate('min(1, 2'));

  // Semantic errors.
  expectThrows<ArgumentError>('unknown variable', () => evaluate('q + 1'));
  expectThrows<ArgumentError>(
      'unknown function', () => evaluate('foo(1)'));
  expectThrows<ArgumentError>('min arity low', () => evaluate('min(1)'));
  expectThrows<ArgumentError>(
      'min arity high', () => evaluate('min(1, 2, 3)'));
  expectThrows<ArgumentError>('abs arity', () => evaluate('abs(1, 2)'));
  expectThrows<ArgumentError>(
      'variable not shadowing call error', () => evaluate('sqrt(1, 2)'));

  // Trickier precedence and associativity.
  check('unary in product', evaluate('-2*3'), -6);
  check('unary after mul', evaluate('2*-3'), -6);
  check('pow chain with unary', evaluate('-2^2^2'), -16);
  check('exp of unary chain', evaluate('2^- -1'), 2);
  check('add of powers', evaluate('2^3+3^2'), 17);
  check('percent chain', evaluate('20%7%4'), 2);
  check('unary bound', evaluate('-3^2+1'), -8);
  check('double exponent', evaluate('4^0.5'), 2.0);
  check('one over', evaluate('1/0') == double.infinity, true);

  // Variables shadow nothing built in; names are case-sensitive.
  expectThrows<ArgumentError>(
      'case sensitive vars', () => evaluate('X', variables: {'x': 1}));
  check('var in call', evaluate('min(x, 2)', variables: {'x': 9}), 2);
  check('numbers with zeros', evaluate('007 + 0.50'), 7.5);
  if (failures > 0) exit(1);
  print('edge ok');
}
