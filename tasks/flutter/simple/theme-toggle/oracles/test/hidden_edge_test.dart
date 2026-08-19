import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:theme_toggle/main.dart';

Brightness labelBrightness(WidgetTester tester) {
  final context = tester.element(find.byKey(const Key('mode-label')));
  return Theme.of(context).brightness;
}

void main() {
  testWidgets('toggling repeatedly keeps working', (tester) async {
    await tester.pumpWidget(const ThemeToggleApp());
    await tester.tap(find.byKey(const Key('theme-switch')));
    await tester.pumpAndSettle();
    expect(labelBrightness(tester), Brightness.dark);
    await tester.tap(find.byKey(const Key('theme-switch')));
    await tester.pumpAndSettle();
    expect(labelBrightness(tester), Brightness.light);
    await tester.tap(find.byKey(const Key('theme-switch')));
    await tester.pumpAndSettle();
    expect(labelBrightness(tester), Brightness.dark);
  });

  testWidgets('scaffold background actually darkens', (tester) async {
    await tester.pumpWidget(const ThemeToggleApp());
    final lightColor = Theme.of(
      tester.element(find.byType(Scaffold)),
    ).scaffoldBackgroundColor;
    await tester.tap(find.byKey(const Key('theme-switch')));
    await tester.pumpAndSettle();
    final darkColor = Theme.of(
      tester.element(find.byType(Scaffold)),
    ).scaffoldBackgroundColor;
    expect(darkColor, isNot(equals(lightColor)));
    final luminance = darkColor.computeLuminance();
    expect(luminance, lessThan(0.2));
  });
}
