import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connectivity_banner/connectivity_banner.dart';

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
  testWidgets('quiet stream shows no banner, child always visible', (tester) async {
    final controller = StreamController<bool>.broadcast();
    await tester.pumpWidget(host(controller.stream));
    await tester.pump();
    expect(find.text('content'), findsOneWidget);
    expect(find.byKey(const Key('offline-banner')), findsNothing);
    expect(find.byKey(const Key('online-banner')), findsNothing);
    await controller.close();
  });

  testWidgets('false shows the offline banner and it persists', (tester) async {
    final controller = StreamController<bool>.broadcast();
    await tester.pumpWidget(host(controller.stream));
    await emit(tester, controller, false);
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    await controller.close();
  });

  testWidgets('true after offline shows Back online for 2 seconds', (tester) async {
    final controller = StreamController<bool>.broadcast();
    await tester.pumpWidget(host(controller.stream));
    await emit(tester, controller, false);
    await emit(tester, controller, true);
    expect(find.byKey(const Key('online-banner')), findsOneWidget);
    expect(find.text('Back online'), findsOneWidget);
    expect(find.byKey(const Key('offline-banner')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byKey(const Key('online-banner')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('online-banner')), findsNothing);
    expect(find.byKey(const Key('offline-banner')), findsNothing);
    await controller.close();
  });
}
