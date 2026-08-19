import 'package:flutter/material.dart';

void main() => runApp(const KanbanApp());

/// Placeholder — the board still needs to be built.
class KanbanApp extends StatelessWidget {
  const KanbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Board',
      home: Scaffold(
        body: Center(child: Text('The board is empty. Very empty.')),
      ),
    );
  }
}
