import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:theme_toggle/main.dart';

Brightness labelBrightness(WidgetTester tester) {
  final context = tester.element(find.byKey(const Key('mode-label')));
  return Theme.of(context).brightness;
}

String labelText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('mode-label'))).data ?? '';
}

void main() {
  testWidgets('starts in light mode', (tester) async {
    await tester.pumpWidget(const ThemeToggleApp());
    expect(labelBrightness(tester), Brightness.light);
    expect(labelText(tester), 'Light mode');
  });

  testWidgets('switch turns the theme dark', (tester) async {
    await tester.pumpWidget(const ThemeToggleApp());
    await tester.tap(find.byKey(const Key('theme-switch')));
    await tester.pumpAndSettle();
    expect(labelBrightness(tester), Brightness.dark);
    expect(labelText(tester), 'Dark mode');
  });
}
