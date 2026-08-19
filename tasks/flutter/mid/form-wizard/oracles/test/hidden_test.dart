import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:form_wizard/main.dart';

String stepText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('step-indicator'))).data ?? '';
}

Future<void> fillStep1(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('name-field')), 'Ada Runcorn');
  await tester.enterText(find.byKey(const Key('email-field')), 'ada@mail.org');
  await tester.tap(find.byKey(const Key('next-button')));
  await tester.pump();
}

Future<void> fillStep2(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('street-field')), '12 Loom Lane');
  await tester.enterText(find.byKey(const Key('city-field')), 'Weaverton');
  await tester.tap(find.byKey(const Key('next-button')));
  await tester.pump();
}

void main() {
  testWidgets('starts on step 1 without a back button', (tester) async {
    await tester.pumpWidget(const WizardApp());
    expect(stepText(tester), 'Step 1 of 3');
    expect(find.byKey(const Key('name-field')), findsOneWidget);
    expect(find.byKey(const Key('back-button')), findsNothing);
  });

  testWidgets('happy path reaches review with the entered values', (tester) async {
    await tester.pumpWidget(const WizardApp());
    await fillStep1(tester);
    expect(stepText(tester), 'Step 2 of 3');
    await fillStep2(tester);
    expect(stepText(tester), 'Step 3 of 3');
    expect(
      tester.widget<Text>(find.byKey(const Key('review-name'))).data,
      'Ada Runcorn',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('review-email'))).data,
      'ada@mail.org',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('review-street'))).data,
      '12 Loom Lane',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('review-city'))).data,
      'Weaverton',
    );
  });

  testWidgets('submit replaces the wizard with the success view', (tester) async {
    await tester.pumpWidget(const WizardApp());
    await fillStep1(tester);
    await fillStep2(tester);
    await tester.tap(find.byKey(const Key('submit-button')));
    await tester.pump();
    expect(find.byKey(const Key('wizard-success')), findsOneWidget);
    expect(find.text('All set!'), findsOneWidget);
    expect(find.byKey(const Key('step-indicator')), findsNothing);
    expect(find.byKey(const Key('submit-button')), findsNothing);
  });
}
