import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cart_notifier/cart_model.dart';
import 'package:cart_notifier/cart_screen.dart';
import 'package:cart_notifier/main.dart';

Widget host(CartModel model) => MaterialApp(
      home: Scaffold(body: CartScreen(model: model)),
    );

void main() {
  testWidgets('screen reflects external model changes', (tester) async {
    final model = CartModel();
    await tester.pumpWidget(host(model));
    expect(find.byKey(const Key('empty-cart')), findsOneWidget);
    expect(find.text('Your cart is empty'), findsOneWidget);

    model.add('Beans', 2.50);
    model.add('Beans', 2.50);
    await tester.pump();
    expect(find.byKey(const Key('empty-cart')), findsNothing);
    expect(find.text('Beans x 2'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('cart-total'))).data,
      r'Total: $5.00',
    );
  });

  testWidgets('inc and dec buttons drive the model', (tester) async {
    final model = CartModel();
    model.add('Tea', 3.80);
    await tester.pumpWidget(host(model));
    await tester.tap(find.byKey(const Key('inc-Tea')));
    await tester.pump();
    expect(model.items.single.quantity, 2);
    expect(model.items.single.price, 3.80);
    expect(find.text('Tea x 2'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('cart-total'))).data,
      r'Total: $7.60',
    );
    await tester.tap(find.byKey(const Key('dec-Tea')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dec-Tea')));
    await tester.pump();
    expect(model.items, isEmpty);
    expect(find.byKey(const Key('empty-cart')), findsOneWidget);
  });

  testWidgets('CartApp shop buttons feed the shared cart', (tester) async {
    await tester.pumpWidget(const CartApp());
    await tester.tap(find.byKey(const Key('shop-Beans')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('shop-Rice')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('shop-Beans')));
    await tester.pump();
    expect(find.text('Beans x 2'), findsOneWidget);
    expect(find.text('Rice x 1'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('cart-total'))).data,
      r'Total: $6.20',
    );
  });
}
