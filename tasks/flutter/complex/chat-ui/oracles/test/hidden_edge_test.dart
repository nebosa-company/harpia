import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chat_ui/chat_message.dart';
import 'package:chat_ui/chat_screen.dart';

final DateTime kNow = DateTime(2026, 3, 10, 15, 0);

Future<void> pump(
  WidgetTester tester,
  List<ChatMessage> messages, {
  String currentUser = 'Ana',
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ChatScreen(
        messages: messages,
        currentUser: currentUser,
        now: kNow,
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('no unread messages, no divider', (tester) async {
    await pump(tester, [
      ChatMessage(sender: 'Maya', text: 'Hi', sentAt: DateTime(2026, 3, 10, 9, 0)),
      ChatMessage(sender: 'Ana', text: 'Hello', sentAt: DateTime(2026, 3, 10, 9, 1)),
    ]);
    expect(find.byKey(const Key('unread-divider')), findsNothing);
  });

  testWidgets('own unread messages do not trigger the divider', (tester) async {
    await pump(tester, [
      ChatMessage(sender: 'Maya', text: 'Hi', sentAt: DateTime(2026, 3, 10, 9, 0)),
      ChatMessage(
        sender: 'Ana',
        text: 'Unsynced draft',
        sentAt: DateTime(2026, 3, 10, 9, 1),
        read: false,
      ),
    ]);
    expect(find.byKey(const Key('unread-divider')), findsNothing);
  });

  testWidgets('exactly 5 minutes starts a new run, 4:59 does not', (tester) async {
    await pump(tester, [
      ChatMessage(sender: 'Maya', text: 'One', sentAt: DateTime(2026, 3, 10, 9, 0)),
      ChatMessage(sender: 'Maya', text: 'Two', sentAt: DateTime(2026, 3, 10, 9, 5)),
    ]);
    expect(find.text('Maya'), findsNWidgets(2), reason: '5-minute gap splits');

    await pump(tester, [
      ChatMessage(sender: 'Maya', text: 'One', sentAt: DateTime(2026, 3, 10, 9, 0)),
      ChatMessage(
        sender: 'Maya',
        text: 'Two',
        sentAt: DateTime(2026, 3, 10, 9, 4, 59),
      ),
    ]);
    expect(find.text('Maya'), findsOneWidget, reason: 'under 5 minutes groups');
  });

  testWidgets('a conversation of only own messages shows no labels', (tester) async {
    await pump(tester, [
      ChatMessage(sender: 'Ana', text: 'Note one', sentAt: DateTime(2026, 3, 10, 9, 0)),
      ChatMessage(sender: 'Ana', text: 'Note two', sentAt: DateTime(2026, 3, 10, 10, 0)),
    ]);
    expect(find.text('Ana'), findsNothing);
    expect(find.byKey(const Key('day-header-2026-03-10')), findsOneWidget);
  });

  testWidgets('old dates render as zero-padded ISO', (tester) async {
    await pump(tester, [
      ChatMessage(sender: 'Maya', text: 'Ancient', sentAt: DateTime(2025, 1, 7, 8, 5)),
    ]);
    final header = find.byKey(const Key('day-header-2025-01-07'));
    expect(header, findsOneWidget);
    expect(
      find.descendant(of: header, matching: find.text('2025-01-07')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(const Key('msg-0')), matching: find.text('08:05')),
      findsOneWidget,
    );
  });

  testWidgets('midnight boundary splits the day and the run', (tester) async {
    await pump(tester, [
      ChatMessage(sender: 'Maya', text: 'Late', sentAt: DateTime(2026, 3, 9, 23, 59)),
      ChatMessage(sender: 'Maya', text: 'Early', sentAt: DateTime(2026, 3, 10, 0, 0)),
    ]);
    expect(find.byKey(const Key('day-header-2026-03-09')), findsOneWidget);
    expect(find.byKey(const Key('day-header-2026-03-10')), findsOneWidget);
    expect(find.text('Maya'), findsNWidgets(2),
        reason: 'a new day always restarts the run');
  });
}
