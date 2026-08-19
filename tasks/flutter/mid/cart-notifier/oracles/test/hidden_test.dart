import 'package:flutter_test/flutter_test.dart';

import 'package:cart_notifier/cart_model.dart';

void main() {
  test('add appends and merges lines', () {
    final cart = CartModel();
    cart.add('Beans', 2.50);
    cart.add('Rice', 1.20);
    cart.add('Beans', 2.50);
    expect(cart.items.length, 2);
    expect(cart.items[0].name, 'Beans');
    expect(cart.items[0].quantity, 2);
    expect(cart.items[1].name, 'Rice');
    expect(cart.items[1].quantity, 1);
  });

  test('totals reflect quantity and price', () {
    final cart = CartModel();
    expect(cart.totalQuantity, 0);
    expect(cart.totalPrice, 0.0);
    cart.add('Beans', 2.50);
    cart.add('Beans', 2.50);
    cart.add('Tea', 3.80);
    expect(cart.totalQuantity, 3);
    expect(cart.totalPrice, closeTo(8.80, 1e-9));
  });

  test('add notifies exactly once per call', () {
    final cart = CartModel();
    var notifications = 0;
    cart.addListener(() => notifications++);
    cart.add('Beans', 2.50);
    expect(notifications, 1);
    cart.add('Beans', 2.50);
    expect(notifications, 2);
  });

  test('removeOne decrements and drops empty lines', () {
    final cart = CartModel();
    cart.add('Beans', 2.50);
    cart.add('Beans', 2.50);
    cart.removeOne('Beans');
    expect(cart.items.single.quantity, 1);
    cart.removeOne('Beans');
    expect(cart.items, isEmpty);
  });

  test('removeOne on unknown name is silent', () {
    final cart = CartModel();
    cart.add('Beans', 2.50);
    var notifications = 0;
    cart.addListener(() => notifications++);
    cart.removeOne('Ghost');
    expect(notifications, 0);
    expect(cart.items.single.name, 'Beans');
  });

  test('clear empties and notifies only when non-empty', () {
    final cart = CartModel();
    var notifications = 0;
    cart.addListener(() => notifications++);
    cart.clear();
    expect(notifications, 0);
    cart.add('Beans', 2.50);
    notifications = 0;
    cart.clear();
    expect(notifications, 1);
    expect(cart.items, isEmpty);
    expect(cart.totalQuantity, 0);
  });

  test('items is not modifiable from outside', () {
    final cart = CartModel();
    cart.add('Beans', 2.50);
    expect(() => cart.items.clear(), throwsUnsupportedError);
  });
}
