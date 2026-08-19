import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_list/main.dart';

Future<void> addItem(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('todo-input')), text);
  await tester.tap(find.byKey(const Key('todo-add')));
  await tester.pump();
}

void main() {
  testWidgets('empty state is shown until an item exists', (tester) async {
    await tester.pumpWidget(const TodoApp());
    expect(find.byKey(const Key('empty-state')), findsOneWidget);
    expect(find.text('Nothing to do'), findsOneWidget);
    await addItem(tester, 'Buy milk');
    expect(find.byKey(const Key('empty-state')), findsNothing);
    await tester.tap(find.byKey(const Key('remove-Buy milk')));
    await tester.pump();
    expect(find.byKey(const Key('empty-state')), findsOneWidget);
  });

  testWidgets('whitespace-only input adds nothing', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await addItem(tester, '   ');
    await addItem(tester, '');
    expect(find.byKey(const Key('empty-state')), findsOneWidget);
  });

  testWidgets('duplicates are ignored but input clears', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await addItem(tester, 'Buy milk');
    await addItem(tester, 'Buy milk');
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.byKey(const Key('remove-Buy milk')), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('todo-input')),
    );
    expect(field.controller?.text ?? '', isEmpty);
  });
}
