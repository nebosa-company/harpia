import 'package:flutter/material.dart';

void main() => runApp(const CardsApp());

/// Placeholder — the expansion card still needs to be built.
class CardsApp extends StatelessWidget {
  const CardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Cards',
      home: Scaffold(
        body: Center(child: Text('Flat cards only, for now')),
      ),
    );
  }
}
