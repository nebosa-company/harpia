import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:three_tabs/main.dart';

String titleText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('appbar-title'))).data ?? '';
}

void main() {
  testWidgets('swiping the page view updates tab and title', (tester) async {
    await tester.pumpWidget(const TabsApp());
    await tester.drag(find.byKey(const Key('home-view')), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-view')), findsOneWidget);
    expect(titleText(tester), 'Search');
  });

  testWidgets('round trip returns to Home', (tester) async {
    await tester.pumpWidget(const TabsApp());
    await tester.tap(find.byKey(const Key('tab-profile')));
    await tester.pumpAndSettle();
    expect(titleText(tester), 'Profile');
    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-view')), findsOneWidget);
    expect(find.byKey(const Key('profile-view')), findsNothing);
    expect(titleText(tester), 'Home');
  });
}
