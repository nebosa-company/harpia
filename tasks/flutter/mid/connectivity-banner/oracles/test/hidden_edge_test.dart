import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connectivity_banner/connectivity_banner.dart';
import 'package:connectivity_banner/main.dart';

Widget host(Stream<bool> status) => MaterialApp(
      home: Scaffold(
        body: ConnectivityBanner(
          status: status,
          child: const Text('content'),
        ),
      ),
    );

/// Emit one status event and let delivery plus rebuild settle.
Future<void> emit(
  WidgetTester tester,
  StreamController<bool> controller,
  bool online,
) async {
  controller.add(online);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a true with no offline period shows nothing', (tester) async {
    final controller = StreamController<bool>.broadcast();
    await tester.pumpWidget(host(controller.stream));
    await emit(tester, controller, true);
    expect(find.byKey(const Key('online-banner')), findsNothing);
    expect(find.byKey(const Key('offline-banner')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('online-banner')), findsNothing);
    await controller.close();
  });

  testWidgets('repeated false events do not stack banners', (tester) async {
    final controller = StreamController<bool>.broadcast();
    await tester.pumpWidget(host(controller.stream));
    await emit(tester, controller, false);
    await emit(tester, controller, false);
    await emit(tester, controller, false);
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.text('No internet connection'), findsOneWidget);
    await controller.close();
  });

  testWidgets('offline during the online countdown cancels the hide', (tester) async {
    final controller = StreamController<bool>.broadcast();
    await tester.pumpWidget(host(controller.stream));
    await emit(tester, controller, false);
    await emit(tester, controller, true);
    expect(find.byKey(const Key('online-banner')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await emit(tester, controller, false);
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.byKey(const Key('online-banner')), findsNothing);
    // The old 2-second hide must not fire against the offline banner.
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    await controller.close();
  });

  testWidgets('demo app toggle drives the banner', (tester) async {
    await tester.pumpWidget(const ConnectivityDemoApp());
    expect(find.byKey(const Key('offline-banner')), findsNothing);
    await tester.tap(find.byKey(const Key('toggle-connectivity')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggle-connectivity')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('online-banner')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byKey(const Key('online-banner')), findsNothing);
  });
}
