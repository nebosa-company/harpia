import 'dart:io';

import '../lib/mustache.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected <$expected>, got <$actual>');
    failures++;
  }
}

void main() {
  check('plain text', render('just text', {}), 'just text');
  check('interpolation', render('Hello {{name}}!', {'name': 'Ada'}),
      'Hello Ada!');
  check('spaces in tag', render('{{ name }}', {'name': 'x'}), 'x');
  check('missing is empty', render('[{{ghost}}]', {}), '[]');
  check('null is empty', render('[{{v}}]', {'v': null}), '[]');
  check('number', render('{{n}}', {'n': 42}), '42');
  check('double', render('{{n}}', {'n': 2.5}), '2.5');
  check('bool', render('{{b}}', {'b': true}), 'true');
  check('escaped', render('{{x}}', {'x': '<b>&</b>'}),
      '&lt;b&gt;&amp;&lt;/b&gt;');
  check('quotes escaped', render('{{q}}', {'q': 'a"b\'c'}),
      'a&quot;b&#39;c');
  check('raw', render('{{{x}}}', {'x': '<b>&'}), '<b>&');
  check('raw with spaces', render('{{{ x }}}', {'x': '<i>'}), '<i>');

  check('section list', render('{{#items}}[{{.}}]{{/items}}', {
    'items': [1, 2, 3]
  }), '[1][2][3]');
  check('section map', render('{{#user}}{{name}}{{/user}}', {
    'user': {'name': 'Ada'}
  }), 'Ada');
  check('section true', render('{{#on}}yes{{/on}}', {'on': true}), 'yes');
  check('section false', render('{{#on}}yes{{/on}}', {'on': false}), '');
  check('section missing', render('{{#none}}yes{{/none}}', {}), '');
  check('section empty list', render('{{#items}}x{{/items}}', {
    'items': <Object?>[]
  }), '');
  check('inverted empty', render('{{^items}}none{{/items}}', {
    'items': <Object?>[]
  }), 'none');
  check('inverted present', render('{{^items}}none{{/items}}', {
    'items': [1]
  }), '');
  check('inverted false', render('{{^on}}off{{/on}}', {'on': false}), 'off');

  check('dotted', render('{{a.b}}', {
    'a': {'b': 7}
  }), '7');
  check('parent visible', render('{{#items}}{{sep}}{{.}}{{/items}}', {
    'items': [1, 2],
    'sep': '|'
  }), '|1|2');
  check('comment', render('a{{! ignore me }}b', {}), 'ab');
  check('list of maps', render('{{#rows}}{{id}};{{/rows}}', {
    'rows': [
      {'id': 1},
      {'id': 2}
    ]
  }), '1;2;');
  check(
      'nested sections',
      render('{{#a}}{{#b}}{{v}}{{/b}}{{/a}}', {
        'a': {
          'b': {'v': 'deep'}
        }
      }),
      'deep');
  check('text preserved', render('  {{v}}  \n', {'v': 'x'}), '  x  \n');
  if (failures > 0) exit(1);
  print('core ok');
}
