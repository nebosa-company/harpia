import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expansion_card/expansion_card.dart';
import 'package:expansion_card/main.dart';

double heightOf(WidgetTester tester, Key key) {
  return tester.getSize(find.byKey(key)).height;
}

void main() {
  testWidgets('custom duration is honored', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExpansionCard(
          title: 'Slow',
          duration: const Duration(milliseconds: 1000),
          child: const SizedBox(height: 100, width: 100),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('expansion-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final mid = heightOf(tester, const Key('expansion-body'));
    expect(mid, greaterThan(1));
    expect(mid, lessThan(99));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(
      heightOf(tester, const Key('expansion-body')),
      moreOrLessEquals(100, epsilon: 0.5),
    );
  });

  testWidgets('tapping mid-flight reverses from the current position', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExpansionCard(
          title: 'Reverse',
          child: const SizedBox(height: 120, width: 100),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('expansion-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final mid = heightOf(tester, const Key('expansion-body'));
    expect(mid, greaterThan(1));
    // Reverse half-way; it must come back down without jumping to full.
    await tester.tap(find.byKey(const Key('expansion-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    final reversing = heightOf(tester, const Key('expansion-body'));
    expect(reversing, lessThan(mid + 0.5));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(
      heightOf(tester, const Key('expansion-body')),
      moreOrLessEquals(0, epsilon: 0.5),
    );
  });

  testWidgets('two cards expand independently in CardsApp', (tester) async {
    await tester.pumpWidget(const CardsApp());
    expect(find.text('Shipping details'), findsOneWidget);
    expect(find.text('Payment methods'), findsOneWidget);
    final headers = find.byKey(const Key('expansion-header'));
    expect(headers, findsNWidgets(2));
    final bodies = find.byKey(const Key('expansion-body'));
    expect(bodies, findsNWidgets(2));
    expect(tester.getSize(bodies.first).height, 0);
    expect(tester.getSize(bodies.last).height, 0);

    await tester.tap(headers.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final first = tester.getSize(bodies.first).height;
    final second = tester.getSize(bodies.last).height;
    expect(first, greaterThan(10));
    expect(second, 0);
  });
}
