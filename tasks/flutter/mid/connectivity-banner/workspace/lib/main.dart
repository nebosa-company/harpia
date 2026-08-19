import 'package:flutter/material.dart';

void main() => runApp(const ConnectivityDemoApp());

/// Placeholder — the banner still needs to be built.
class ConnectivityDemoApp extends StatelessWidget {
  const ConnectivityDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Field app',
      home: Scaffold(
        body: Center(child: Text('Always assume the best about the network')),
      ),
    );
  }
}
