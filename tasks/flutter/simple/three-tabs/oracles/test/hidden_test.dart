import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:three_tabs/main.dart';

String titleText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('appbar-title'))).data ?? '';
}

void main() {
  testWidgets('starts on Home', (tester) async {
    await tester.pumpWidget(const TabsApp());
    expect(find.byKey(const Key('home-view')), findsOneWidget);
    expect(find.text('Welcome home'), findsOneWidget);
    expect(find.byKey(const Key('search-view')), findsNothing);
    expect(find.byKey(const Key('profile-view')), findsNothing);
    expect(titleText(tester), 'Home');
  });

  testWidgets('tapping tabs switches page and title', (tester) async {
    await tester.pumpWidget(const TabsApp());
    await tester.tap(find.byKey(const Key('tab-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-view')), findsOneWidget);
    expect(find.text('Search the catalog'), findsOneWidget);
    expect(find.byKey(const Key('home-view')), findsNothing);
    expect(titleText(tester), 'Search');

    await tester.tap(find.byKey(const Key('tab-profile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-view')), findsOneWidget);
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.byKey(const Key('search-view')), findsNothing);
    expect(titleText(tester), 'Profile');
  });
}
