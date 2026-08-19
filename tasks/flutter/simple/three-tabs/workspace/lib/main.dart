import 'package:flutter/material.dart';

void main() => runApp(const TabsApp());

/// Placeholder — the tabbed layout still needs to be built.
class TabsApp extends StatelessWidget {
  const TabsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Sections',
      home: Scaffold(
        body: Center(child: Text('One section, so far')),
      ),
    );
  }
}
