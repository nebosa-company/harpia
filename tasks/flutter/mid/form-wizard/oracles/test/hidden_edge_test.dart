import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:form_wizard/main.dart';

String stepText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('step-indicator'))).data ?? '';
}

void main() {
  testWidgets('step 1 validation blocks advancing', (tester) async {
    await tester.pumpWidget(const WizardApp());
    await tester.tap(find.byKey(const Key('next-button')));
    await tester.pump();
    expect(stepText(tester), 'Step 1 of 3');
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Enter a valid email'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('name-field')), 'Ada');
    await tester.enterText(find.byKey(const Key('email-field')), 'not-an-email');
    await tester.tap(find.byKey(const Key('next-button')));
    await tester.pump();
    expect(stepText(tester), 'Step 1 of 3');
    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('step 2 validation blocks advancing', (tester) async {
    await tester.pumpWidget(const WizardApp());
    await tester.enterText(find.byKey(const Key('name-field')), 'Ada');
    await tester.enterText(find.byKey(const Key('email-field')), 'a@b.c');
    await tester.tap(find.byKey(const Key('next-button')));
    await tester.pump();
    expect(stepText(tester), 'Step 2 of 3');
    await tester.tap(find.byKey(const Key('next-button')));
    await tester.pump();
    expect(stepText(tester), 'Step 2 of 3');
    expect(find.text('Street is required'), findsOneWidget);
    expect(find.text('City is required'), findsOneWidget);
  });

  testWidgets('going back preserves everything typed', (tester) async {
    await tester.pumpWidget(const WizardApp());
    await tester.enterText(find.byKey(const Key('name-field')), 'Ada');
    await tester.enterText(find.byKey(const Key('email-field')), 'a@b.c');
    await tester.tap(find.byKey(const Key('next-button')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('street-field')), '12 Loom');
    await tester.enterText(find.byKey(const Key('city-field')), 'Weaverton');

    await tester.tap(find.byKey(const Key('back-button')));
    await tester.pump();
    expect(stepText(tester), 'Step 1 of 3');
    expect(find.widgetWithText(TextFormField, 'Ada'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'a@b.c'), findsOneWidget);

    await tester.tap(find.byKey(const Key('next-button')));
    await tester.pump();
    expect(stepText(tester), 'Step 2 of 3');
    expect(find.widgetWithText(TextFormField, '12 Loom'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Weaverton'), findsOneWidget);
  });

  testWidgets('review step has back but no next', (tester) async {
    await tester.pumpWidget(const WizardApp());
    await tester.enterText(find.byKey(const Key('name-field')), 'Ada');
    await tester.enterText(find.byKey(const Key('email-field')), 'a@b.c');
    await tester.tap(find.byKey(const Key('next-button')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('street-field')), '12 Loom');
    await tester.enterText(find.byKey(const Key('city-field')), 'Weaverton');
    await tester.tap(find.byKey(const Key('next-button')));
    await tester.pump();
    expect(stepText(tester), 'Step 3 of 3');
    expect(find.byKey(const Key('back-button')), findsOneWidget);
    expect(find.byKey(const Key('submit-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('back-button')));
    await tester.pump();
    expect(stepText(tester), 'Step 2 of 3');
  });
}
