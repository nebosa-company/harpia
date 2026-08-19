import 'dart:io';

import '../lib/schema_validator.dart';

int failures = 0;

bool deepEq(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEq(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

void check(String label, Object? actual, Object? expected) {
  if (!deepEq(actual, expected)) {
    print('FAIL $label: expected $expected, got $actual');
    failures++;
  }
}

void main() {
  check('string ok', validate('hi', {'type': 'string'}), <String>[]);
  check('string bad', validate(5, {'type': 'string'}), ['/: expected string']);
  check('integer strict', validate(3.5, {'type': 'integer'}),
      ['/: expected integer']);
  check('number takes int', validate(3, {'type': 'number'}), <String>[]);
  check('number takes double', validate(3.5, {'type': 'number'}), <String>[]);
  check('null type', validate(null, {'type': 'null'}), <String>[]);
  check('bool not number', validate(true, {'type': 'number'}),
      ['/: expected number']);
  check('enum ok', validate('red', {'enum': ['red', 'green']}), <String>[]);
  check('enum bad', validate('blue', {'enum': ['red', 'green']}),
      ['/: value not in enum']);
  check('isValid true', isValid(7, {'type': 'integer', 'minimum': 5}), true);
  check('isValid false', isValid(4, {'type': 'integer', 'minimum': 5}), false);

  final person = {
    'type': 'object',
    'required': ['name'],
    'properties': {
      'name': {'type': 'string', 'minLength': 1},
      'age': {'type': 'integer', 'minimum': 0},
    },
  };
  check('object ok', validate({'name': 'Ada', 'age': 36}, person), <String>[]);
  check('missing required', validate({'age': 3}, person),
      ["/: missing required property 'name'"]);
  check('nested type', validate({'name': 'Ada', 'age': 'old'}, person),
      ['/age: expected integer']);

  final nested = {
    'type': 'object',
    'properties': {
      'users': {
        'type': 'array',
        'items': {
          'type': 'object',
          'required': ['email'],
          'properties': {
            'email': {'type': 'string'},
          },
        },
      },
    },
  };
  check(
      'deep path',
      validate({
        'users': [
          {'email': 'a@x.io'},
          {'email': 42},
        ]
      }, nested),
      ['/users/1/email: expected string']);
  check(
      'deep required',
      validate({
        'users': [<String, Object?>{}]
      }, nested),
      ["/users/0: missing required property 'email'"]);
  if (failures > 0) exit(1);
  print('core ok');
}
