import 'dart:io';

import '../lib/inline_markdown.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected <$expected>, got <$actual>');
    failures++;
  }
}

void main() {
  check('escaped star', renderInline(r'\*lit\*'), '*lit*');
  check('escaped backtick', renderInline(r'\`x\`'), '`x`');
  check('escaped bracket link', renderInline(r'\[a](u)'), '[a](u)');
  check('escaped backslash', renderInline(r'\\'), r'\');
  check('unknown escape kept', renderInline(r'a\qb'), r'a\qb');
  check('space edged star', renderInline('2 * 3 * 4'), '2 * 3 * 4');
  check('unclosed bold', renderInline('**unclosed'), '**unclosed');
  check('unpaired backtick', renderInline('a ` b'), 'a ` b');
  check('empty emphasis literal', renderInline('**'), '**');
  check('link needs url part', renderInline('[text]'), '[text]');
  check('link url no spaces', renderInline('[t](a b)'), '[t](a b)');
  check('url paren via escape', renderInline(r'[a](u\)v)'),
      '<a href="u)v">a</a>');
  check('url quote escaped', renderInline('[t](u"v)'),
      '<a href="u&quot;v">t</a>');
  check('bold before italic', renderInline('***x***'),
      '<strong>*x</strong>*');
  check('adjacent bold', renderInline('**a****b**'),
      '<strong>a</strong><strong>b</strong>');
  check('code before link', renderInline('[`c<d`](u)'),
      '<a href="u"><code>c&lt;d</code></a>');
  check('escape shields pairing', renderInline(r'*a\*'), r'*a*');
  check('newline is plain', renderInline('a\nb'), 'a\nb');
  if (failures > 0) exit(1);
  print('edge ok');
}
