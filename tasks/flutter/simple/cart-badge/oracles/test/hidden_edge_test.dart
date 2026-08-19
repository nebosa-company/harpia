import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cart_badge/main.dart';

void main() {
  testWidgets('clear empties the cart and hides the badge', (tester) async {
    await tester.pumpWidget(const ShopApp());
    await tester.tap(find.byKey(const Key('add-Cheese')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-Olives')));
    await tester.pump();
    expect(find.byKey(const Key('cart-badge')), findsOneWidget);
    await tester.tap(find.byKey(const Key('clear-cart')));
    await tester.pump();
    expect(find.byKey(const Key('cart-badge')), findsNothing);
  });

  testWidgets('adding after clear starts counting from one again', (tester) async {
    await tester.pumpWidget(const ShopApp());
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('add-Apples')));
      await tester.pump();
    }
    expect(
      tester.widget<Text>(find.byKey(const Key('cart-badge'))).data,
      '4',
    );
    await tester.tap(find.byKey(const Key('clear-cart')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-Bread')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('cart-badge'))).data,
      '1',
    );
  });
}
