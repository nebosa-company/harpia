import 'dart:io';

import '../lib/path_router.dart';

int failures = 0;

bool mapEq(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (a[key] != b[key]) return false;
  }
  return true;
}

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected $expected, got $actual');
    failures++;
  }
}

void checkMatch(String label, RouteMatch<String>? m, String? handler,
    Map<String, String>? params) {
  if (handler == null) {
    if (m != null) {
      print('FAIL $label: expected null, got ${m.handler} ${m.params}');
      failures++;
    }
    return;
  }
  if (m == null) {
    print('FAIL $label: expected $handler $params, got null');
    failures++;
    return;
  }
  if (m.handler != handler || !mapEq(m.params, params!)) {
    print('FAIL $label: expected $handler $params, '
        'got ${m.handler} ${m.params}');
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
  final r = Router<String>();
  expectThrows<ArgumentError>('no leading slash', () => r.add('users', 'x'));
  expectThrows<ArgumentError>('empty segment', () => r.add('/a//b', 'x'));
  expectThrows<ArgumentError>('bare colon', () => r.add('/a/:', 'x'));
  expectThrows<ArgumentError>('bare star', () => r.add('/a/*', 'x'));
  expectThrows<ArgumentError>(
      'wildcard not last', () => r.add('/a/*rest/b', 'x'));
  r.add('/dup/:id', 'first');
  expectThrows<ArgumentError>(
      'equivalent duplicate', () => r.add('/dup/:name', 'second'));
  expectThrows<ArgumentError>(
      'exact duplicate', () => r.add('/dup/:id', 'third'));
  r.add('/dup/literal', 'fine');
  checkMatch('after failures still works', r.match('/dup/9'), 'first',
      {'id': '9'});

  // Precedence: param beats wildcard at the same position.
  final p = Router<String>();
  p.add('/f/*rest', 'wild');
  p.add('/f/:one', 'param');
  p.add('/f/lit', 'lit');
  checkMatch('literal first', p.match('/f/lit'), 'lit', {});
  checkMatch('param over wildcard', p.match('/f/zzz'), 'param', {'one': 'zzz'});
  checkMatch('wildcard for deeper', p.match('/f/x/y'), 'wild',
      {'rest': 'x/y'});

  // Registration order must not matter for precedence.
  final q = Router<String>();
  q.add('/g/:x', 'param');
  q.add('/g/lit', 'lit');
  checkMatch('late literal wins', q.match('/g/lit'), 'lit', {});

  // Backtracking across a deeper dead end.
  final bt = Router<String>();
  bt.add('/x/a/:p/end', 'via-a');
  bt.add('/x/:q/b/end', 'via-q');
  checkMatch('deep backtrack', bt.match('/x/a/b/end'), 'via-a', {'p': 'b'});
  checkMatch('fallback branch', bt.match('/x/c/b/end'), 'via-q', {'q': 'c'});

  // Percent decoding.
  final d = Router<String>();
  d.add('/v/:val', 'v');
  d.add('/w/*rest', 'w');
  checkMatch('encoded slash in param', d.match('/v/a%2Fb'), 'v',
      {'val': 'a/b'});
  checkMatch('plus stays', d.match('/v/a+b'), 'v', {'val': 'a+b'});
  checkMatch('malformed stays raw', d.match('/v/100%zz'), 'v',
      {'val': '100%zz'});
  checkMatch('wildcard decodes segments', d.match('/w/x%20y/z'), 'w',
      {'rest': 'x y/z'});

  // Path hygiene.
  checkMatch('double slash', d.match('/v//a'), null, null);
  checkMatch('relative path', d.match('v/a'), null, null);
  checkMatch('empty string', d.match(''), null, null);

  // Root does not match non-root.
  final rootOnly = Router<String>();
  rootOnly.add('/', 'root');
  checkMatch('root only root', rootOnly.match('/x'), null, null);
  checkMatch('root slash', rootOnly.match('/'), 'root', {});
  if (failures > 0) exit(1);
  print('edge ok');
}
