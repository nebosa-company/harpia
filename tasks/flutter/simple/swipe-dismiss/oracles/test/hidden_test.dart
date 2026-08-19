import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:swipe_dismiss/main.dart';

Future<void> dismiss(WidgetTester tester, String name) async {
  await tester.drag(find.byKey(Key('chore-$name')), const Offset(500, 0));
  await tester.pumpAndSettle();
}

Future<void> drainSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('all four chores are listed initially', (tester) async {
    await tester.pumpWidget(const ChoresApp());
    for (final name in [
      'Water plants',
      'Take out trash',
      'Feed the cat',
      'Vacuum hall',
    ]) {
      expect(find.text(name), findsOneWidget);
      expect(find.byKey(Key('chore-$name')), findsOneWidget);
    }
  });

  testWidgets('swiping removes exactly that chore', (tester) async {
    await tester.pumpWidget(const ChoresApp());
    await dismiss(tester, 'Take out trash');
    expect(find.text('Take out trash'), findsNothing);
    expect(find.text('Water plants'), findsOneWidget);
    expect(find.text('Feed the cat'), findsOneWidget);
    expect(find.text('Vacuum hall'), findsOneWidget);
    await drainSnackBar(tester);
  });

  testWidgets('a snackbar names the removed chore', (tester) async {
    await tester.pumpWidget(const ChoresApp());
    await dismiss(tester, 'Feed the cat');
    expect(find.text('Removed Feed the cat'), findsOneWidget);
    await drainSnackBar(tester);
    expect(find.text('Removed Feed the cat'), findsNothing);
  });
}
