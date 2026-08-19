import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kanban_board/main.dart';

Future<void> setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> dragCard(
  WidgetTester tester,
  String title,
  String columnKey,
) async {
  final card = find.byKey(Key('card-$title'));
  final target = find.byKey(Key(columnKey));
  final gesture = await tester.startGesture(tester.getCenter(card));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
}

String countOf(WidgetTester tester, String slug) {
  return tester.widget<Text>(find.byKey(Key('count-$slug'))).data ?? '';
}

bool cardInColumn(WidgetTester tester, String title, String columnKey) {
  final cardCenter = tester.getCenter(find.byKey(Key('card-$title')));
  final rect = tester.getRect(find.byKey(Key(columnKey)));
  return rect.contains(cardCenter);
}

void main() {
  testWidgets('seed board renders with correct counts', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(const KanbanApp());
    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(countOf(tester, 'todo'), '2');
    expect(countOf(tester, 'inprogress'), '1');
    expect(countOf(tester, 'done'), '0');
    expect(cardInColumn(tester, 'Design logo', 'column-todo'), isTrue);
    expect(cardInColumn(tester, 'Write specs', 'column-todo'), isTrue);
    expect(cardInColumn(tester, 'Build API', 'column-inprogress'), isTrue);
  });

  testWidgets('dragging a card moves it and appends at the end', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(const KanbanApp());
    await dragCard(tester, 'Design logo', 'column-inprogress');
    expect(countOf(tester, 'todo'), '1');
    expect(countOf(tester, 'inprogress'), '2');
    expect(cardInColumn(tester, 'Design logo', 'column-inprogress'), isTrue);
    expect(cardInColumn(tester, 'Design logo', 'column-todo'), isFalse);
    final existing = tester.getTopLeft(find.byKey(const Key('card-Build API'))).dy;
    final moved = tester.getTopLeft(find.byKey(const Key('card-Design logo'))).dy;
    expect(moved, greaterThan(existing),
        reason: 'moved card must be appended below the existing one');
  });

  testWidgets('an empty column accepts drops', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(const KanbanApp());
    await dragCard(tester, 'Build API', 'column-done');
    expect(countOf(tester, 'inprogress'), '0');
    expect(countOf(tester, 'done'), '1');
    expect(cardInColumn(tester, 'Build API', 'column-done'), isTrue);
  });
}
