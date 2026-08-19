import 'package:flutter/material.dart';

void main() => runApp(const ChatApp());

/// Placeholder — the transcript renderer still needs to be built.
class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Threads',
      home: Scaffold(
        body: Center(child: Text('No messages. Blissful silence.')),
      ),
    );
  }
}
