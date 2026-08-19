import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:swipe_dismiss/main.dart';

Future<void> dismiss(WidgetTester tester, String name) async {
  await tester.drag(find.byKey(Key('chore-$name')), const Offset(-500, 0));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('order of remaining chores is preserved', (tester) async {
    await tester.pumpWidget(const ChoresApp());
    await dismiss(tester, 'Take out trash');
    final plantsY = tester.getTopLeft(find.byKey(const Key('chore-Water plants'))).dy;
    final catY = tester.getTopLeft(find.byKey(const Key('chore-Feed the cat'))).dy;
    final hallY = tester.getTopLeft(find.byKey(const Key('chore-Vacuum hall'))).dy;
    expect(plantsY, lessThan(catY));
    expect(catY, lessThan(hallY));
  });

  testWidgets('removing every chore reveals the done message', (tester) async {
    await tester.pumpWidget(const ChoresApp());
    expect(find.byKey(const Key('all-done')), findsNothing);
    for (final name in [
      'Water plants',
      'Take out trash',
      'Feed the cat',
      'Vacuum hall',
    ]) {
      await dismiss(tester, name);
    }
    expect(find.byKey(const Key('all-done')), findsOneWidget);
    expect(find.text('All chores done!'), findsOneWidget);
  });
}
