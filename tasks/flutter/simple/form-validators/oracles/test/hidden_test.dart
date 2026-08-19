import 'package:flutter_test/flutter_test.dart';

import 'package:form_validators/validators.dart';

void main() {
  group('validateUsername', () {
    test('requires a value', () {
      expect(validateUsername(null), 'Username is required');
      expect(validateUsername(''), 'Username is required');
      expect(validateUsername('   '), 'Username is required');
    });

    test('requires at least 3 characters', () {
      expect(validateUsername('ab'), 'Username must be at least 3 characters');
      expect(validateUsername('  ab  '), 'Username must be at least 3 characters');
      expect(validateUsername('abc'), isNull);
    });

    test('restricts the alphabet', () {
      expect(
        validateUsername('ab cd'),
        'Username may only contain letters, numbers, and underscores',
      );
      expect(
        validateUsername('ab-cd'),
        'Username may only contain letters, numbers, and underscores',
      );
      expect(validateUsername('ab_cd9'), isNull);
      expect(validateUsername('User_42'), isNull);
    });
  });

  group('validateEmail', () {
    test('requires a value', () {
      expect(validateEmail(null), 'Email is required');
      expect(validateEmail(''), 'Email is required');
      expect(validateEmail('  '), 'Email is required');
    });

    test('accepts plausible addresses', () {
      expect(validateEmail('a@b.c'), isNull);
      expect(validateEmail('jo.doe@mail.example.org'), isNull);
      expect(validateEmail('  jo@mail.org  '), isNull);
    });

    test('rejects malformed addresses', () {
      expect(validateEmail('plain'), 'Enter a valid email address');
      expect(validateEmail('a@b'), 'Enter a valid email address');
      expect(validateEmail('@b.c'), 'Enter a valid email address');
      expect(validateEmail('a@@b.c'), 'Enter a valid email address');
      expect(validateEmail('a@b.'), 'Enter a valid email address');
      expect(validateEmail('a@.c'), 'Enter a valid email address');
      expect(validateEmail('a b@c.d'), 'Enter a valid email address');
    });
  });

  group('validatePassword', () {
    test('requires a value', () {
      expect(validatePassword(null), 'Password is required');
      expect(validatePassword(''), 'Password is required');
    });

    test('requires 8 characters', () {
      expect(validatePassword('abc1234'), 'Password must be at least 8 characters');
      expect(validatePassword('abcd1234'), isNull);
    });

    test('requires a digit', () {
      expect(validatePassword('abcdefgh'), 'Password must contain a number');
      expect(validatePassword('abcdefg1'), isNull);
    });
  });
}
