import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:form_validators/main.dart';

void main() {
  testWidgets('submitting an empty form shows all three errors', (tester) async {
    await tester.pumpWidget(const SignupApp());
    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pump();
    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.byKey(const Key('signup-success')), findsNothing);
  });

  testWidgets('partially valid form blocks success', (tester) async {
    await tester.pumpWidget(const SignupApp());
    await tester.enterText(find.byKey(const Key('username-field')), 'jo');
    await tester.enterText(find.byKey(const Key('email-field')), 'jo@mail.org');
    await tester.enterText(find.byKey(const Key('password-field')), 'secret99x');
    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pump();
    expect(find.text('Username must be at least 3 characters'), findsOneWidget);
    expect(find.byKey(const Key('signup-success')), findsNothing);
  });

  testWidgets('valid form shows the success text', (tester) async {
    await tester.pumpWidget(const SignupApp());
    await tester.enterText(find.byKey(const Key('username-field')), 'jo_doe');
    await tester.enterText(find.byKey(const Key('email-field')), 'jo@mail.org');
    await tester.enterText(find.byKey(const Key('password-field')), 'secret99x');
    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pump();
    expect(find.byKey(const Key('signup-success')), findsOneWidget);
    expect(find.text('Account created'), findsOneWidget);
    expect(find.text('Username must be at least 3 characters'), findsNothing);
  });
}
