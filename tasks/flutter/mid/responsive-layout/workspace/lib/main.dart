import 'package:flutter/material.dart';

void main() => runApp(const ResponsiveApp());

/// Placeholder — the adaptive shell still needs to be built.
class ResponsiveApp extends StatelessWidget {
  const ResponsiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Mail shell',
      home: Scaffold(
        body: Center(child: Text('One size fits nobody')),
      ),
    );
  }
}
