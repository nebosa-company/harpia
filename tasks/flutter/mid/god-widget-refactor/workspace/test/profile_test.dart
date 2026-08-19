import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:profile_page/main.dart';

void main() {
  testWidgets('shows the profile header', (tester) async {
    await tester.pumpWidget(const ProfileApp());
    expect(find.text('Ada Runcorn'), findsOneWidget);
    expect(find.text('@ada'), findsOneWidget);
  });

  testWidgets('follow button toggles', (tester) async {
    await tester.pumpWidget(const ProfileApp());
    expect(find.text('Follow'), findsOneWidget);
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pump();
    expect(find.text('Following'), findsWidgets);
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pump();
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('shows the stats', (tester) async {
    await tester.pumpWidget(const ProfileApp());
    expect(find.text('128'), findsOneWidget);
    expect(find.text('3421'), findsOneWidget);
    expect(find.text('210'), findsOneWidget);
  });

  testWidgets('settings switches flip', (tester) async {
    await tester.pumpWidget(const ProfileApp());
    final tile = find.byKey(const Key('setting-Dark mode'));
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    await tester.tap(tile);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
  });
}
