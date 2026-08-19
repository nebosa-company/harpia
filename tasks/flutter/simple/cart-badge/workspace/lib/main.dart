import 'package:flutter/material.dart';

void main() => runApp(const ShopApp());

/// Placeholder — the shop screen still needs to be built.
class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Corner shop',
      home: Scaffold(
        body: Center(child: Text('Shop under construction')),
      ),
    );
  }
}
