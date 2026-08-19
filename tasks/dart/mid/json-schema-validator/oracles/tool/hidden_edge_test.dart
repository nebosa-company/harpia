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
  check('minimum inclusive', validate(5, {'minimum': 5}), <String>[]);
  check('minimum breach', validate(4, {'minimum': 5}), ['/: must be >= 5']);
  check('maximum breach', validate(6.5, {'maximum': 6}), ['/: must be <= 6']);
  check('double bound text', validate(1, {'minimum': 2.5}),
      ['/: must be >= 2.5']);
  check('minLength inclusive', validate('ab', {'minLength': 2}), <String>[]);
  check('minLength breach', validate('a', {'minLength': 2}),
      ['/: length must be >= 2']);
  check('maxLength breach', validate('abcd', {'maxLength': 3}),
      ['/: length must be <= 3']);
  check(
      'bounds ignored for strings', validate('abc', {'minimum': 5}), <String>[]);
  check('lengths ignored for nums', validate(7, {'minLength': 5}), <String>[]);
  check('object keywords ignored for lists', validate([1], {'required': ['x']}),
      <String>[]);

  check(
      'additionalProperties false',
      validate({'a': 1, 'b': 2}, {
        'properties': {
          'a': {'type': 'integer'}
        },
        'additionalProperties': false,
      }),
      ['/b: unexpected property']);
  check(
      'additionalProperties default',
      validate({'a': 1, 'b': 2}, {
        'properties': {
          'a': {'type': 'integer'}
        },
      }),
      <String>[]);

  // Multi-error ordering: required (schema order), then properties (schema
  // order), then additionalProperties (data order).
  check(
      'error order',
      validate({
        'name': '',
        'extra': true,
      }, {
        'type': 'object',
        'required': ['name', 'id'],
        'properties': {
          'name': {'minLength': 1},
        },
        'additionalProperties': false,
      }),
      [
        "/: missing required property 'id'",
        '/name: length must be >= 1',
        '/extra: unexpected property',
      ]);

  check('items multiple errors',
      validate([1, 'x', 3.5], {'items': {'type': 'integer'}}),
      ['/1: expected integer', '/2: expected integer']);

  check('type stops keywords', validate('str', {
    'type': 'integer',
    'minimum': 5,
  }), ['/: expected integer']);

  check('enum stops deeper', validate({'a': 1}, {
    'enum': [
      {'a': 2}
    ],
    'properties': {
      'a': {'type': 'string'}
    },
  }), ['/: value not in enum']);

  check('enum deep equality', validate({'a': [1, 2]}, {
    'enum': [
      {'a': [1, 2]}
    ],
  }), <String>[]);
  if (failures > 0) exit(1);
  print('edge ok');
}
