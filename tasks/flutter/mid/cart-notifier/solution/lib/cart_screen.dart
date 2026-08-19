import 'package:flutter/material.dart';

import 'cart_model.dart';

/// Renders a [CartModel] and rebuilds on every notification.
class CartScreen extends StatelessWidget {
  const CartScreen({required this.model, super.key});

  final CartModel model;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final items = model.items;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Your cart is empty', key: Key('empty-cart')),
              )
            else
              for (final item in items)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        '${item.name} x ${item.quantity}',
                        key: Key('line-${item.name}'),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          key: Key('inc-${item.name}'),
                          icon: const Icon(Icons.add),
                          onPressed: () => model.add(item.name, item.price),
                        ),
                        IconButton(
                          key: Key('dec-${item.name}'),
                          icon: const Icon(Icons.remove),
                          onPressed: () => model.removeOne(item.name),
                        ),
                      ],
                    ),
                  ],
                ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Total: \$${model.totalPrice.toStringAsFixed(2)}',
                key: const Key('cart-total'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        );
      },
    );
  }
}
