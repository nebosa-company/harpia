import 'dart:io';

import '../lib/mustache.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected <$expected>, got <$actual>');
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
  expectThrows<FormatException>('unclosed tag', () => render('a {{x', {}));
  expectThrows<FormatException>(
      'unclosed triple', () => render('{{{x}} b', {}));
  expectThrows<FormatException>('empty name', () => render('{{}}', {}));
  expectThrows<FormatException>('empty section name', () => render('{{#}}x{{/}}', {}));
  expectThrows<FormatException>(
      'close without open', () => render('{{/sec}}', {}));
  expectThrows<FormatException>(
      'mismatched close', () => render('{{#a}}x{{/b}}', {'a': true}));
  expectThrows<FormatException>(
      'wrong nesting order', () => render('{{#a}}{{#b}}x{{/a}}{{/b}}', {
            'a': {'b': true}
          }));
  expectThrows<FormatException>(
      'left open', () => render('{{#a}}x', {'a': true}));

  // Truthiness: 0 and empty string render sections.
  check('zero truthy', render('{{#n}}[{{.}}]{{/n}}', {'n': 0}), '[0]');
  check('empty string truthy', render('{{#s}}yes{{/s}}', {'s': ''}), 'yes');
  check('inverted zero', render('{{^n}}no{{/n}}', {'n': 0}), '');

  // Dotted resolution.
  check('deep dotted', render('{{a.b.c}}', {
    'a': {
      'b': {'c': 'x'}
    }
  }), 'x');
  check('dotted through non-map', render('[{{a.b.c}}]', {
    'a': {'b': 5}
  }), '[]');
  check('dotted missing head', render('[{{z.b}}]', {}), '[]');
  check('dotted in section', render('{{#o}}{{p.q}}{{/o}}', {
    'o': {
      'p': {'q': 9}
    }
  }), '9');
  check('dotted prefers inner frame', render('{{#o}}{{a.b}}{{/o}}', {
    'o': {
      'a': {'b': 'inner'}
    },
    'a': {'b': 'outer'}
  }), 'inner');

  // Shadowing and fallback across the stack.
  check('inner shadows outer', render('{{#o}}{{v}}{{/o}}', {
    'o': {'v': 'in'},
    'v': 'out'
  }), 'in');
  check('fallback to outer', render('{{#o}}{{v}}{{/o}}', {
    'o': {'other': 1},
    'v': 'out'
  }), 'out');
  check('null key present is empty', render('{{#o}}[{{v}}]{{/o}}', {
    'o': {'v': null},
    'v': 'out'
  }), '[]');

  // Nested list sections with implicit iterator.
  check('nested lists', render('{{#rows}}({{#.}}{{.}},{{/.}}){{/rows}}', {
    'rows': [
      [1, 2],
      [3]
    ]
  }), '(1,2,)(3,)');

  // Sections repeat their inner tags per item, comments vanish anywhere.
  check('comment in section', render('{{#i}}a{{! hi }}b{{/i}}', {
    'i': [1, 2]
  }), 'abab');

  // Braces in plain text that are not tags stay put.
  check('single braces', render('{ not a tag }', {}), '{ not a tag }');
  check('stray close braces', render('a }} b', {}), 'a }} b');
  if (failures > 0) exit(1);
  print('edge ok');
}
