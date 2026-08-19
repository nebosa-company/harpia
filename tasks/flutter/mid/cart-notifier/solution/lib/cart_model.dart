import 'package:flutter/foundation.dart';

/// One line in the cart.
class CartItem {
  CartItem({required this.name, required this.price, this.quantity = 1});

  final String name;
  final double price;
  int quantity;
}

/// Shopping cart with change notifications.
class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  void add(String name, double price) {
    final existing = _items.where((i) => i.name == name).toList();
    if (existing.isEmpty) {
      _items.add(CartItem(name: name, price: price));
    } else {
      existing.first.quantity++;
    }
    notifyListeners();
  }

  void removeOne(String name) {
    final index = _items.indexWhere((i) => i.name == name);
    if (index < 0) {
      return;
    }
    final item = _items[index];
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      _items.removeAt(index);
    }
    notifyListeners();
  }

  int get totalQuantity => _items.fold(0, (sum, i) => sum + i.quantity);

  double get totalPrice =>
      _items.fold(0.0, (sum, i) => sum + i.price * i.quantity);

  void clear() {
    if (_items.isEmpty) {
      return;
    }
    _items.clear();
    notifyListeners();
  }
}
