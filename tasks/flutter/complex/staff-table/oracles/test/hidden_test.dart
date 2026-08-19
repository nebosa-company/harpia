import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:staff_directory/main.dart';

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1500);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const StaffApp());
  await tester.pump();
}

double rowY(WidgetTester tester, String name) {
  return tester.getTopLeft(find.byKey(Key('row-$name'))).dy;
}

void expectOrder(WidgetTester tester, List<String> names) {
  for (var i = 0; i + 1 < names.length; i++) {
    expect(
      rowY(tester, names[i]),
      lessThan(rowY(tester, names[i + 1])),
      reason: '${names[i]} must render above ${names[i + 1]}',
    );
  }
}

Future<void> tapHeader(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

String countText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('count-label'))).data ?? '';
}

void main() {
  testWidgets('initial order follows the roster, all rows shown', (tester) async {
    await pumpApp(tester);
    expect(countText(tester), 'Showing 12 of 12');
    expectOrder(tester, [
      'Imre Fodor',
      'Sana Qureshi',
      'Beatriz Lima',
      'Owen Whitfield',
      'Grace Okafor',
    ]);
    expect(find.byKey(const Key('sort-icon')), findsNothing);
  });

  testWidgets('salary sorts numerically both ways', (tester) async {
    await pumpApp(tester);
    await tapHeader(tester, 'header-salary');
    expectOrder(tester, [
      'Marta Kowalska',
      'Lars Nyström',
      'Owen Whitfield',
      'Aicha Benali',
      'Grace Okafor',
      'Tomás Herrera',
      'Sana Qureshi',
      'Yuki Tanabe',
      'Beatriz Lima',
      'Imre Fodor',
      'Priya Raman',
      'Dmitri Volkov',
    ]);
    expect(
      tester.widget<Icon>(find.byKey(const Key('sort-icon'))).icon,
      Icons.arrow_upward,
    );
    await tapHeader(tester, 'header-salary');
    expectOrder(tester, [
      'Dmitri Volkov',
      'Priya Raman',
      'Imre Fodor',
      'Beatriz Lima',
      'Marta Kowalska',
    ]);
    expect(
      tester.widget<Icon>(find.byKey(const Key('sort-icon'))).icon,
      Icons.arrow_downward,
    );
  });

  testWidgets('name sorts lexicographically', (tester) async {
    await pumpApp(tester);
    await tapHeader(tester, 'header-name');
    expectOrder(tester, [
      'Aicha Benali',
      'Beatriz Lima',
      'Dmitri Volkov',
      'Grace Okafor',
      'Imre Fodor',
      'Lars Nyström',
      'Marta Kowalska',
      'Owen Whitfield',
      'Priya Raman',
      'Sana Qureshi',
      'Tomás Herrera',
      'Yuki Tanabe',
    ]);
  });

  testWidgets('filter matches name or department, case-insensitive', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('filter-field')), 'eng');
    await tester.pump();
    expect(countText(tester), 'Showing 4 of 12');
    expect(find.byKey(const Key('row-Imre Fodor')), findsOneWidget);
    expect(find.byKey(const Key('row-Beatriz Lima')), findsOneWidget);
    expect(find.byKey(const Key('row-Dmitri Volkov')), findsOneWidget);
    expect(find.byKey(const Key('row-Priya Raman')), findsOneWidget);
    expect(find.byKey(const Key('row-Sana Qureshi')), findsNothing);

    await tester.enterText(find.byKey(const Key('filter-field')), 'an');
    await tester.pump();
    expect(countText(tester), 'Showing 3 of 12');
    expect(find.byKey(const Key('row-Sana Qureshi')), findsOneWidget);
    expect(find.byKey(const Key('row-Yuki Tanabe')), findsOneWidget);
    expect(find.byKey(const Key('row-Priya Raman')), findsOneWidget);
  });

  testWidgets('filter plus sort compose', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('filter-field')), 'ENG');
    await tester.pump();
    await tapHeader(tester, 'header-salary');
    expectOrder(tester, [
      'Beatriz Lima',
      'Imre Fodor',
      'Priya Raman',
      'Dmitri Volkov',
    ]);
    expect(countText(tester), 'Showing 4 of 12');
  });
}
