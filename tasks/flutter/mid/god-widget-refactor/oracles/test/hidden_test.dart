import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:profile_page/widgets/profile_header.dart';
import 'package:profile_page/widgets/settings_section.dart';
import 'package:profile_page/widgets/stats_row.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('ProfileHeader renders and reports follow taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(ProfileHeader(
      name: 'Test Person',
      handle: '@tp',
      following: false,
      onFollowToggle: () => taps++,
    )));
    expect(find.text('Test Person'), findsOneWidget);
    expect(find.text('@tp'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('ProfileHeader label follows the following flag', (tester) async {
    await tester.pumpWidget(host(ProfileHeader(
      name: 'X',
      handle: '@x',
      following: true,
      onFollowToggle: () {},
    )));
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('StatsRow shows the three keyed columns', (tester) async {
    await tester.pumpWidget(host(const StatsRow(
      posts: 5,
      followers: 10,
      following: 2,
    )));
    for (final entry in {
      'stat-posts': '5',
      'stat-followers': '10',
      'stat-following': '2',
    }.entries) {
      expect(
        find.descendant(
          of: find.byKey(Key(entry.key)),
          matching: find.text(entry.value),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('SettingsSection renders entries and reports changes', (tester) async {
    final changes = <String, bool>{};
    await tester.pumpWidget(host(SettingsSection(
      values: const {'Alpha': true, 'Beta': false},
      onChanged: (title, value) => changes[title] = value,
    )));
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('setting-Alpha'))).value,
      isTrue,
    );
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('setting-Beta'))).value,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('setting-Beta')));
    await tester.pump();
    expect(changes, {'Beta': true});
  });
}
