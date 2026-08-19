import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cart_badge/main.dart';

String badgeText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('cart-badge'))).data ?? '';
}

void main() {
  testWidgets('all four products are listed with add buttons', (tester) async {
    await tester.pumpWidget(const ShopApp());
    for (final name in ['Apples', 'Bread', 'Cheese', 'Olives']) {
      expect(find.text(name), findsOneWidget);
      expect(find.byKey(Key('add-$name')), findsOneWidget);
    }
  });

  testWidgets('no badge while the cart is empty', (tester) async {
    await tester.pumpWidget(const ShopApp());
    expect(find.byKey(const Key('cart-badge')), findsNothing);
  });

  testWidgets('badge counts total units across products', (tester) async {
    await tester.pumpWidget(const ShopApp());
    await tester.tap(find.byKey(const Key('add-Apples')));
    await tester.pump();
    expect(badgeText(tester), '1');
    await tester.tap(find.byKey(const Key('add-Bread')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-Bread')));
    await tester.pump();
    expect(badgeText(tester), '3');
  });
}
