import 'package:flutter/material.dart';

import 'chat_message.dart';
import 'chat_screen.dart';

void main() => runApp(const ChatApp());

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime(2026, 3, 10, 15, 0);
    return MaterialApp(
      title: 'Threads',
      home: Scaffold(
        appBar: AppBar(title: const Text('Maya')),
        body: ChatScreen(
          currentUser: 'Ana',
          now: now,
          messages: [
            ChatMessage(
              sender: 'Maya',
              text: 'Lunch tomorrow?',
              sentAt: DateTime(2026, 3, 9, 12, 0),
            ),
            ChatMessage(
              sender: 'Ana',
              text: 'Sure, noon works',
              sentAt: DateTime(2026, 3, 9, 12, 3),
            ),
            ChatMessage(
              sender: 'Maya',
              text: 'See you at the usual place',
              sentAt: DateTime(2026, 3, 10, 11, 45),
              read: false,
            ),
          ],
        ),
      ),
    );
  }
}
