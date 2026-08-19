import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expansion_card/expansion_card.dart';

Widget host({Duration? duration}) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ExpansionCard(
              title: 'Details',
              duration: duration ?? const Duration(milliseconds: 300),
              child: const SizedBox(height: 120, width: 200),
            ),
          ],
        ),
      ),
    );

double bodyHeight(WidgetTester tester) {
  return tester.getSize(find.byKey(const Key('expansion-body'))).height;
}

void main() {
  testWidgets('starts collapsed with the child clipped away', (tester) async {
    await tester.pumpWidget(host());
    expect(bodyHeight(tester), 0);
    final chevron = tester.widget<RotationTransition>(
      find.byKey(const Key('expansion-chevron')),
    );
    expect(chevron.turns.value, 0.0);
    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets('tap expands through intermediate heights', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('expansion-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final mid = bodyHeight(tester);
    expect(mid, greaterThan(1));
    expect(mid, lessThan(119));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(bodyHeight(tester), moreOrLessEquals(120, epsilon: 0.5));
    final chevron = tester.widget<RotationTransition>(
      find.byKey(const Key('expansion-chevron')),
    );
    expect(chevron.turns.value, moreOrLessEquals(0.5, epsilon: 0.01));
  });

  testWidgets('second tap collapses back to zero', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('expansion-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(bodyHeight(tester), moreOrLessEquals(120, epsilon: 0.5));
    await tester.tap(find.byKey(const Key('expansion-header')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(bodyHeight(tester), moreOrLessEquals(0, epsilon: 0.5));
    final chevron = tester.widget<RotationTransition>(
      find.byKey(const Key('expansion-chevron')),
    );
    expect(chevron.turns.value, moreOrLessEquals(0.0, epsilon: 0.01));
  });
}
