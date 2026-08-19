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
  check('plain', renderInline('plain text'), 'plain text');
  check('escaping', renderInline('a < b & c > d'), 'a &lt; b &amp; c &gt; d');
  check('bold', renderInline('**bold**'), '<strong>bold</strong>');
  check('italic', renderInline('*it*'), '<em>it</em>');
  check('both', renderInline('**bold** *it*'),
      '<strong>bold</strong> <em>it</em>');
  check('code', renderInline('`x = 1`'), '<code>x = 1</code>');
  check('code escapes html', renderInline('`a<b`'), '<code>a&lt;b</code>');
  check('code shields markdown', renderInline('`*not em*`'),
      '<code>*not em*</code>');
  check('link', renderInline('[go](https://x.io)'),
      '<a href="https://x.io">go</a>');
  check('link url escaped', renderInline('[go](x?a=1&b=2)'),
      '<a href="x?a=1&amp;b=2">go</a>');
  check('link label styled', renderInline('[**hi**](u)'),
      '<a href="u"><strong>hi</strong></a>');
  check('nested em in strong', renderInline('**a *b* c**'),
      '<strong>a <em>b</em> c</strong>');
  check('em wraps strong', renderInline('*mix **b** e*'),
      '<em>mix <strong>b</strong> e</em>');
  check('mid sentence', renderInline('say **loud** now'),
      'say <strong>loud</strong> now');
  check('empty', renderInline(''), '');
  if (failures > 0) exit(1);
  print('core ok');
}
