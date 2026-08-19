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

void main() {
  final router = Router<String>();
  router.add('/users/new', 'users-new');
  router.add('/users/:id', 'users-id');
  router.add('/users/:id/posts/:post', 'user-post');
  router.add('/static/*file', 'static');
  router.add('/a/:x/c', 'a-x-c');
  router.add('/a/b/d', 'a-b-d');
  router.add('/', 'root');

  checkMatch('literal beats param', router.match('/users/new'), 'users-new',
      {});
  checkMatch('param', router.match('/users/42'), 'users-id', {'id': '42'});
  checkMatch('decoded param', router.match('/users/ab%20cd'), 'users-id',
      {'id': 'ab cd'});
  checkMatch('two params', router.match('/users/42/posts/7'), 'user-post',
      {'id': '42', 'post': '7'});
  checkMatch('wildcard rest', router.match('/static/css/app.css'), 'static',
      {'file': 'css/app.css'});
  checkMatch('wildcard single', router.match('/static/app.js'), 'static',
      {'file': 'app.js'});
  checkMatch('wildcard empty', router.match('/static'), 'static', {'file': ''});
  checkMatch('backtrack to param', router.match('/a/b/c'), 'a-x-c', {'x': 'b'});
  checkMatch('literal branch', router.match('/a/b/d'), 'a-b-d', {});
  checkMatch('root', router.match('/'), 'root', {});
  checkMatch('no match short', router.match('/users'), null, null);
  checkMatch('no match long', router.match('/users/1/2'), null, null);
  checkMatch('unknown top', router.match('/nope'), null, null);
  checkMatch('trailing slash path', router.match('/users/42/'), 'users-id',
      {'id': '42'});

  final trailing = Router<String>();
  trailing.add('/things/', 'things');
  checkMatch('trailing slash pattern', trailing.match('/things'), 'things', {});
  if (failures > 0) exit(1);
  print('core ok');
}
