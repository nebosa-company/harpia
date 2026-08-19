import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chat_ui/chat_message.dart';
import 'package:chat_ui/chat_screen.dart';

final DateTime kNow = DateTime(2026, 3, 10, 15, 0);

List<ChatMessage> transcript() => [
      // 2026-03-01 — an old day.
      ChatMessage(sender: 'Maya', text: 'Trip photos?', sentAt: DateTime(2026, 3, 1, 9, 0)),
      ChatMessage(sender: 'Maya', text: 'Sending tonight', sentAt: DateTime(2026, 3, 1, 9, 2)),
      ChatMessage(sender: 'Ana', text: 'Nice!', sentAt: DateTime(2026, 3, 1, 9, 10)),
      // 2026-03-09 — yesterday.
      ChatMessage(sender: 'Maya', text: 'Draft is ready', sentAt: DateTime(2026, 3, 9, 18, 0)),
      ChatMessage(sender: 'Maya', text: 'Take a look', sentAt: DateTime(2026, 3, 9, 18, 6)),
      // 2026-03-10 — today.
      ChatMessage(sender: 'Ana', text: 'Reviewing now', sentAt: DateTime(2026, 3, 10, 14, 30)),
      ChatMessage(sender: 'Maya', text: 'Thanks!', sentAt: DateTime(2026, 3, 10, 14, 40), read: false),
      ChatMessage(sender: 'Maya', text: 'Ping me after', sentAt: DateTime(2026, 3, 10, 14, 41), read: false),
    ];

Future<void> pumpChat(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ChatScreen(
        messages: transcript(),
        currentUser: 'Ana',
        now: kNow,
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('day headers carry the right labels', (tester) async {
    await pumpChat(tester);
    final old = find.byKey(const Key('day-header-2026-03-01'));
    final yesterday = find.byKey(const Key('day-header-2026-03-09'));
    final today = find.byKey(const Key('day-header-2026-03-10'));
    expect(old, findsOneWidget);
    expect(yesterday, findsOneWidget);
    expect(today, findsOneWidget);
    expect(
      find.descendant(of: old, matching: find.text('2026-03-01')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: yesterday, matching: find.text('Yesterday')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: today, matching: find.text('Today')),
      findsOneWidget,
    );
  });

  testWidgets('all bubbles render text and HH:mm timestamps', (tester) async {
    await pumpChat(tester);
    const times = ['09:00', '09:02', '09:10', '18:00', '18:06', '14:30', '14:40', '14:41'];
    const texts = [
      'Trip photos?',
      'Sending tonight',
      'Nice!',
      'Draft is ready',
      'Take a look',
      'Reviewing now',
      'Thanks!',
      'Ping me after',
    ];
    for (var i = 0; i < times.length; i++) {
      final bubble = find.byKey(Key('msg-$i'));
      expect(bubble, findsOneWidget, reason: 'missing bubble msg-$i');
      expect(
        find.descendant(of: bubble, matching: find.text(texts[i])),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bubble, matching: find.text(times[i])),
        findsOneWidget,
        reason: 'msg-$i must show ${times[i]}',
      );
    }
  });

  testWidgets('sender labels appear only at run starts, never for own', (tester) async {
    await pumpChat(tester);
    // Runs for Maya start at msg 0 (day start), msg 3 (new day),
    // msg 4 (6-minute gap), msg 6 (sender change) — four labels.
    expect(find.text('Maya'), findsNWidgets(4));
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('own messages sit right, others left', (tester) async {
    await pumpChat(tester);
    const center = 400.0;
    expect(tester.getCenter(find.byKey(const Key('msg-2'))).dx, greaterThan(center));
    expect(tester.getCenter(find.byKey(const Key('msg-5'))).dx, greaterThan(center));
    expect(tester.getCenter(find.byKey(const Key('msg-0'))).dx, lessThan(center));
    expect(tester.getCenter(find.byKey(const Key('msg-6'))).dx, lessThan(center));
  });

  testWidgets('unread divider sits before the first unread from others', (tester) async {
    await pumpChat(tester);
    final divider = find.byKey(const Key('unread-divider'));
    expect(divider, findsOneWidget);
    expect(find.text('New messages'), findsOneWidget);
    final dividerY = tester.getTopLeft(divider).dy;
    final beforeY = tester.getBottomLeft(find.byKey(const Key('msg-5'))).dy;
    final afterY = tester.getTopLeft(find.byKey(const Key('msg-6'))).dy;
    expect(dividerY, greaterThanOrEqualTo(beforeY));
    expect(dividerY, lessThanOrEqualTo(afterY));
  });
}
