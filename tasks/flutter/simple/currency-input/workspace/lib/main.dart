import 'package:flutter/material.dart';

void main() => runApp(const CurrencyApp());

/// Placeholder — the amount entry screen still needs to be built.
class CurrencyApp extends StatelessWidget {
  const CurrencyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Amount',
      home: Scaffold(
        body: Center(child: Text('Enter an amount — soon')),
      ),
    );
  }
}
