import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldnotes/main.dart';
import 'package:fieldnotes/screens/archive_screen.dart';
import 'package:fieldnotes/store/note_store.dart';

Future<void> swipeAway(WidgetTester tester, int id) async {
  await tester.drag(find.byKey(Key('note-$id')), const Offset(500, 0));
  await tester.pumpAndSettle();
}

void main() {
  test('NoteStore archive, restore, and ordering', () {
    final store = NoteStore();
    store.archive(2);
    expect(store.notes.map((n) => n.id).toList(), [1, 3, 4]);
    expect(store.archivedNotes.map((n) => n.id).toList(), [2]);
    store.archive(4);
    expect(store.notes.map((n) => n.id).toList(), [1, 3]);
    expect(store.archivedNotes.map((n) => n.id).toList(), [2, 4]);
    store.restore(2);
    expect(store.notes.map((n) => n.id).toList(), [1, 2, 3],
        reason: 'restored notes return in id order');
    expect(store.archivedNotes.map((n) => n.id).toList(), [4]);
  });

  testWidgets('swiping archives instead of deleting', (tester) async {
    await tester.pumpWidget(FieldNotesApp());
    await swipeAway(tester, 2);
    expect(find.text('Ridge survey'), findsNothing);
    expect(find.text('Creek water levels'), findsOneWidget);
    expect(find.text('Owl census'), findsOneWidget);
    expect(find.text('Fence repairs'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-archive')));
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveScreen), findsOneWidget);
    final row = find.byKey(const Key('archived-2'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('Ridge survey')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('restore-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive-empty')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Ridge survey'), findsOneWidget);
    final y1 = tester.getTopLeft(find.byKey(const Key('note-1'))).dy;
    final y2 = tester.getTopLeft(find.byKey(const Key('note-2'))).dy;
    final y3 = tester.getTopLeft(find.byKey(const Key('note-3'))).dy;
    expect(y1, lessThan(y2));
    expect(y2, lessThan(y3), reason: 'main list stays ordered by id');
  });

  testWidgets('an empty archive says so', (tester) async {
    await tester.pumpWidget(FieldNotesApp());
    await tester.tap(find.byKey(const Key('open-archive')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive-empty')), findsOneWidget);
    expect(find.text('Archive is empty'), findsOneWidget);
  });

  testWidgets('archiving keeps the note data intact', (tester) async {
    await tester.pumpWidget(FieldNotesApp());
    await swipeAway(tester, 4);
    expect(find.byKey(const Key('note-4')), findsNothing);
    await tester.tap(find.byKey(const Key('open-archive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-4')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('note-4')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('detail-title'))).data,
      'Fence repairs',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('detail-body'))).data,
      'East gate hinge needs a bolt.',
    );
  });
}
