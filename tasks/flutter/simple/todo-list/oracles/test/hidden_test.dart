import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_list/main.dart';

Future<void> addItem(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('todo-input')), text);
  await tester.tap(find.byKey(const Key('todo-add')));
  await tester.pump();
}

void main() {
  testWidgets('added items appear in the list', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await addItem(tester, 'Buy milk');
    expect(find.text('Buy milk'), findsOneWidget);
    await addItem(tester, 'Walk dog');
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Walk dog'), findsOneWidget);
  });

  testWidgets('input is cleared after adding', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await addItem(tester, 'Buy milk');
    final field = tester.widget<TextField>(
      find.byKey(const Key('todo-input')),
    );
    expect(field.controller?.text ?? '', isEmpty);
  });

  testWidgets('remove button deletes exactly that entry', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await addItem(tester, 'Buy milk');
    await addItem(tester, 'Walk dog');
    await addItem(tester, 'Read book');
    await tester.tap(find.byKey(const Key('remove-Walk dog')));
    await tester.pump();
    expect(find.text('Walk dog'), findsNothing);
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Read book'), findsOneWidget);
  });

  testWidgets('trimmed text is stored', (tester) async {
    await tester.pumpWidget(const TodoApp());
    await addItem(tester, '  Buy milk  ');
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.byKey(const Key('remove-Buy milk')), findsOneWidget);
  });
}
