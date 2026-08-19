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

void main() {
  testWidgets('dropping on the own column changes nothing', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(const KanbanApp());
    await dragCard(tester, 'Write specs', 'column-todo');
    expect(countOf(tester, 'todo'), '2');
    expect(countOf(tester, 'inprogress'), '1');
    expect(find.byKey(const Key('card-Write specs')), findsOneWidget);
    final logo = tester.getTopLeft(find.byKey(const Key('card-Design logo'))).dy;
    final specs = tester.getTopLeft(find.byKey(const Key('card-Write specs'))).dy;
    expect(logo, lessThan(specs), reason: 'original order must be preserved');
  });

  testWidgets('cards survive repeated moves across all columns', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(const KanbanApp());
    await dragCard(tester, 'Design logo', 'column-inprogress');
    await dragCard(tester, 'Design logo', 'column-done');
    await dragCard(tester, 'Design logo', 'column-todo');
    expect(countOf(tester, 'todo'), '2');
    expect(countOf(tester, 'inprogress'), '1');
    expect(countOf(tester, 'done'), '0');
    // Round trip appends: Design logo is now below Write specs.
    final specs = tester.getTopLeft(find.byKey(const Key('card-Write specs'))).dy;
    final logo = tester.getTopLeft(find.byKey(const Key('card-Design logo'))).dy;
    expect(logo, greaterThan(specs));
  });

  testWidgets('the add flow appends to To Do and clears the field', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(const KanbanApp());
    await tester.enterText(find.byKey(const Key('new-card-field')), '  Ship it  ');
    await tester.tap(find.byKey(const Key('add-card-button')));
    await tester.pump();
    expect(countOf(tester, 'todo'), '3');
    expect(find.byKey(const Key('card-Ship it')), findsOneWidget);
    final specs = tester.getTopLeft(find.byKey(const Key('card-Write specs'))).dy;
    final ship = tester.getTopLeft(find.byKey(const Key('card-Ship it'))).dy;
    expect(ship, greaterThan(specs));
    final field = tester.widget<TextField>(find.byKey(const Key('new-card-field')));
    expect(field.controller?.text ?? '', isEmpty);
  });

  testWidgets('blank titles are rejected', (tester) async {
    await setSurface(tester);
    await tester.pumpWidget(const KanbanApp());
    await tester.enterText(find.byKey(const Key('new-card-field')), '   ');
    await tester.tap(find.byKey(const Key('add-card-button')));
    await tester.pump();
    expect(countOf(tester, 'todo'), '2');
  });
}
