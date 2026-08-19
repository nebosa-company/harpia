import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldnotes/main.dart';

String detailTitle(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('detail-title'))).data ?? '';
}

String detailBody(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('detail-body'))).data ?? '';
}

Future<void> openNote(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(Key('note-$id')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a note opens exactly that note', (tester) async {
    await tester.pumpWidget(FieldNotesApp());
    await openNote(tester, 2);
    expect(detailTitle(tester), 'Ridge survey');
    expect(detailBody(tester), 'Two new trails on the north face.');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openNote(tester, 3);
    expect(detailTitle(tester), 'Owl census');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openNote(tester, 4);
    expect(detailTitle(tester), 'Fence repairs');
  });

  testWidgets('saving an edit shows up immediately everywhere', (tester) async {
    await tester.pumpWidget(FieldNotesApp());
    await openNote(tester, 2);
    await tester.tap(find.byKey(const Key('edit-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('edit-title-field')),
      'Updated ridge',
    );
    await tester.enterText(
      find.byKey(const Key('edit-body-field')),
      'Three trails now.',
    );
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
    expect(detailTitle(tester), 'Updated ridge');
    expect(detailBody(tester), 'Three trails now.');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Updated ridge'), findsOneWidget);
    expect(find.text('Ridge survey'), findsNothing);
  });

  testWidgets('delete removes exactly the open note', (tester) async {
    await tester.pumpWidget(FieldNotesApp());
    await openNote(tester, 1);
    expect(detailTitle(tester), 'Creek water levels');
    await tester.tap(find.byKey(const Key('delete-button')));
    await tester.pumpAndSettle();
    expect(find.text('Creek water levels'), findsNothing);
    expect(find.text('Ridge survey'), findsOneWidget);
    expect(find.text('Owl census'), findsOneWidget);
    expect(find.text('Fence repairs'), findsOneWidget);
  });

  testWidgets('deleting the newest note works too', (tester) async {
    await tester.pumpWidget(FieldNotesApp());
    await openNote(tester, 4);
    await tester.tap(find.byKey(const Key('delete-button')));
    await tester.pumpAndSettle();
    expect(find.text('Fence repairs'), findsNothing);
    expect(find.text('Creek water levels'), findsOneWidget);
    expect(find.text('Ridge survey'), findsOneWidget);
    expect(find.text('Owl census'), findsOneWidget);
  });
}
