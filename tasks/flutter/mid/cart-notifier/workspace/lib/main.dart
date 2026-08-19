import 'package:flutter/material.dart';

void main() => runApp(const CartApp());

/// Placeholder — model and screen still need to be built.
class CartApp extends StatelessWidget {
  const CartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Groceries',
      home: Scaffold(
        body: Center(child: Text('Cart not wired up yet')),
      ),
    );
  }
}
