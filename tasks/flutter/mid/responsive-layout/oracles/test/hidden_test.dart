import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:responsive_layout/main.dart';

Future<void> pumpAt(WidgetTester tester, double width, double height) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const ResponsiveApp());
  await tester.pump();
}

void expectOnly(String present) {
  const all = ['mobile-layout', 'tablet-layout', 'desktop-layout'];
  for (final key in all) {
    expect(
      find.byKey(Key(key)),
      key == present ? findsOneWidget : findsNothing,
      reason: 'at this width only $present should exist',
    );
  }
}

void main() {
  testWidgets('phone width uses the mobile layout', (tester) async {
    await pumpAt(tester, 400, 800);
    expectOnly('mobile-layout');
    expect(find.byKey(const Key('menu-button')), findsOneWidget);
    expect(find.byKey(const Key('nav-rail')), findsNothing);
    expect(find.byKey(const Key('side-panel')), findsNothing);
  });

  testWidgets('tablet width uses the rail layout', (tester) async {
    await pumpAt(tester, 800, 1024);
    expectOnly('tablet-layout');
    expect(find.byKey(const Key('nav-rail')), findsOneWidget);
    expect(find.byKey(const Key('menu-button')), findsNothing);
    expect(find.byKey(const Key('side-panel')), findsNothing);
  });

  testWidgets('desktop width uses the side panel layout', (tester) async {
    await pumpAt(tester, 1280, 800);
    expectOnly('desktop-layout');
    expect(find.byKey(const Key('side-panel')), findsOneWidget);
    expect(find.byKey(const Key('nav-rail')), findsNothing);
    expect(find.byKey(const Key('menu-button')), findsNothing);
  });

  testWidgets('all four sections are listed in every mode', (tester) async {
    for (final width in [400.0, 800.0, 1280.0]) {
      await pumpAt(tester, width, 900);
      for (final section in ['Inbox', 'Starred', 'Sent', 'Drafts']) {
        expect(find.text(section), findsWidgets,
            reason: '$section missing at width $width');
      }
    }
  });
}
