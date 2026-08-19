import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:profile_page/main.dart';
import 'package:profile_page/widgets/profile_header.dart';
import 'package:profile_page/widgets/settings_section.dart';
import 'package:profile_page/widgets/stats_row.dart';

void main() {
  testWidgets('ProfilePage composes the three extracted widgets', (tester) async {
    await tester.pumpWidget(const ProfileApp());
    expect(find.byType(ProfileHeader), findsOneWidget);
    expect(find.byType(StatsRow), findsOneWidget);
    expect(find.byType(SettingsSection), findsOneWidget);
  });

  testWidgets('behavior is preserved after the split', (tester) async {
    await tester.pumpWidget(const ProfileApp());
    expect(find.text('Ada Runcorn'), findsOneWidget);
    expect(find.text('@ada'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    expect(find.text('3421'), findsOneWidget);
    expect(find.text('210'), findsOneWidget);

    expect(find.text('Follow'), findsOneWidget);
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pump();
    final header = tester.widget<ProfileHeader>(find.byType(ProfileHeader));
    expect(header.following, isTrue);

    final tile = find.byKey(const Key('setting-Dark mode'));
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    await tester.tap(tile);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    final section =
        tester.widget<SettingsSection>(find.byType(SettingsSection));
    expect(section.values['Dark mode'], isTrue);
  });

  testWidgets('the extracted header is stateless: page owns the flag', (tester) async {
    await tester.pumpWidget(const ProfileApp());
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('follow-button')));
    await tester.pump();
    expect(find.text('Follow'), findsOneWidget);
    final header = tester.widget<ProfileHeader>(find.byType(ProfileHeader));
    expect(header.following, isFalse);
  });
}
