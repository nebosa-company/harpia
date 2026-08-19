import 'package:flutter/material.dart';

import 'kanban_board.dart';

void main() => runApp(const KanbanApp());

class KanbanApp extends StatelessWidget {
  const KanbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Board',
      home: Scaffold(
        appBar: AppBar(title: const Text('Board')),
        body: const KanbanBoard(
          initial: {
            'To Do': ['Design logo', 'Write specs'],
            'In Progress': ['Build API'],
            'Done': [],
          },
        ),
      ),
    );
  }
}
