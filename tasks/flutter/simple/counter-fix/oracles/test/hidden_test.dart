import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:counter_fix/main.dart';

String countText(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(const Key('count-label')));
  return text.data ?? '';
}

void main() {
  testWidgets('starts at zero', (tester) async {
    await tester.pumpWidget(const CounterApp());
    expect(countText(tester), '0');
  });

  testWidgets('increment updates the display', (tester) async {
    await tester.pumpWidget(const CounterApp());
    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();
    expect(countText(tester), '1');
    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();
    expect(countText(tester), '3');
  });

  testWidgets('decrement updates the display', (tester) async {
    await tester.pumpWidget(const CounterApp());
    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('increment')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('decrement')));
    await tester.pump();
    expect(countText(tester), '1');
  });
}
