import 'package:flutter/material.dart';

import 'cart_model.dart';
import 'cart_screen.dart';

void main() => runApp(const CartApp());

class CartApp extends StatefulWidget {
  const CartApp({super.key});

  @override
  State<CartApp> createState() => _CartAppState();
}

class _CartAppState extends State<CartApp> {
  final CartModel _model = CartModel();

  static const _products = {
    'Beans': 2.50,
    'Rice': 1.20,
    'Tea': 3.80,
  };

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Groceries',
      home: Scaffold(
        appBar: AppBar(title: const Text('Groceries')),
        body: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final entry in _products.entries)
                  ElevatedButton(
                    key: Key('shop-${entry.key}'),
                    onPressed: () => _model.add(entry.key, entry.value),
                    child: Text(entry.key),
                  ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: CartScreen(model: _model),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
