import 'package:flutter/material.dart';

void main() => runApp(const ShopApp());

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Corner shop',
      home: ShopPage(),
    );
  }
}

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  static const products = ['Apples', 'Bread', 'Cheese', 'Olives'];

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final Map<String, int> _cart = {};

  int get _total => _cart.values.fold(0, (a, b) => a + b);

  void _add(String name) {
    setState(() {
      _cart[name] = (_cart[name] ?? 0) + 1;
    });
  }

  void _clear() {
    setState(() {
      _cart.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corner shop'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.shopping_cart),
              ),
              if (_total > 0)
                Positioned(
                  right: 4,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_total',
                      key: const Key('cart-badge'),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
          TextButton(
            key: const Key('clear-cart'),
            onPressed: _clear,
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        children: [
          for (final name in ShopPage.products)
            ListTile(
              title: Text(name),
              trailing: IconButton(
                key: Key('add-$name'),
                icon: const Icon(Icons.add_shopping_cart),
                onPressed: () => _add(name),
              ),
            ),
        ],
      ),
    );
  }
}
