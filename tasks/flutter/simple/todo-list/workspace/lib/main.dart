import 'package:flutter/material.dart';

void main() => runApp(const TodoApp());

/// Placeholder — the actual todo list still needs to be built.
class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Todos',
      home: Scaffold(
        body: Center(child: Text('Coming soon')),
      ),
    );
  }
}
