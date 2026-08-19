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

void main() {
  testWidgets('599 is still phone, 600 is tablet', (tester) async {
    await pumpAt(tester, 599, 900);
    expect(find.byKey(const Key('mobile-layout')), findsOneWidget);
    expect(find.byKey(const Key('tablet-layout')), findsNothing);

    await pumpAt(tester, 600, 900);
    expect(find.byKey(const Key('tablet-layout')), findsOneWidget);
    expect(find.byKey(const Key('mobile-layout')), findsNothing);
  });

  testWidgets('1023 is still tablet, 1024 is desktop', (tester) async {
    await pumpAt(tester, 1023, 900);
    expect(find.byKey(const Key('tablet-layout')), findsOneWidget);
    expect(find.byKey(const Key('desktop-layout')), findsNothing);

    await pumpAt(tester, 1024, 900);
    expect(find.byKey(const Key('desktop-layout')), findsOneWidget);
    expect(find.byKey(const Key('tablet-layout')), findsNothing);
  });

  testWidgets('side panel is 280 logical pixels wide', (tester) async {
    await pumpAt(tester, 1280, 800);
    final size = tester.getSize(find.byKey(const Key('side-panel')));
    expect(size.width, 280);
  });

  testWidgets('resizing the window live switches layouts', (tester) async {
    await pumpAt(tester, 1280, 800);
    expect(find.byKey(const Key('desktop-layout')), findsOneWidget);
    tester.view.physicalSize = const Size(500, 800);
    await tester.pump();
    expect(find.byKey(const Key('mobile-layout')), findsOneWidget);
    expect(find.byKey(const Key('desktop-layout')), findsNothing);
  });
}
