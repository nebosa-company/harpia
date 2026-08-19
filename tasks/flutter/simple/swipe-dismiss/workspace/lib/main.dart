import 'package:flutter/material.dart';

void main() => runApp(const ChoresApp());

/// Placeholder — the chore list still needs to be built.
class ChoresApp extends StatelessWidget {
  const ChoresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Chores',
      home: Scaffold(
        body: Center(child: Text('No chores yet')),
      ),
    );
  }
}
