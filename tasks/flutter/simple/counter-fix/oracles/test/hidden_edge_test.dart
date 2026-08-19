import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:counter_fix/main.dart';

String countText(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(const Key('count-label')));
  return text.data ?? '';
}

void main() {
  testWidgets('decrement never goes below zero', (tester) async {
    await tester.pumpWidget(const CounterApp());
    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();
    expect(countText(tester), '1');
    await tester.tap(find.byKey(const Key('decrement')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('decrement')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('decrement')));
    await tester.pump();
    expect(countText(tester), '0');
  });

  testWidgets('reset returns the display to zero', (tester) async {
    await tester.pumpWidget(const CounterApp());
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('increment')));
      await tester.pump();
    }
    expect(countText(tester), '5');
    await tester.tap(find.byKey(const Key('reset')));
    await tester.pump();
    expect(countText(tester), '0');
  });
}
