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

void main() {
  testWidgets('department sort is stable within ties', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('header-department')));
    await tester.pump();
    // Ties keep the roster order inside each department.
    expectOrder(tester, [
      'Sana Qureshi',
      'Yuki Tanabe',
      'Tomás Herrera',
      'Imre Fodor',
      'Beatriz Lima',
      'Dmitri Volkov',
      'Priya Raman',
      'Owen Whitfield',
      'Aicha Benali',
      'Grace Okafor',
      'Marta Kowalska',
      'Lars Nyström',
    ]);
  });

  testWidgets('switching columns resets to ascending', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('header-salary')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('header-salary')));
    await tester.pump();
    expect(
      tester.widget<Icon>(find.byKey(const Key('sort-icon'))).icon,
      Icons.arrow_downward,
    );
    await tester.tap(find.byKey(const Key('header-name')));
    await tester.pump();
    expect(
      tester.widget<Icon>(find.byKey(const Key('sort-icon'))).icon,
      Icons.arrow_upward,
    );
    expectOrder(tester, ['Aicha Benali', 'Beatriz Lima', 'Yuki Tanabe']);
  });

  testWidgets('salary is formatted with dollar sign and commas', (tester) async {
    await pumpApp(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('row-Owen Whitfield')),
        matching: find.text(r'$48,000'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('row-Dmitri Volkov')),
        matching: find.text(r'$81,000'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a hopeless filter shows No matches', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('filter-field')), 'zzz');
    await tester.pump();
    expect(find.byKey(const Key('no-rows')), findsOneWidget);
    expect(find.text('No matches'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('count-label'))).data,
      'Showing 0 of 12',
    );
    await tester.enterText(find.byKey(const Key('filter-field')), '');
    await tester.pump();
    expect(find.byKey(const Key('no-rows')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('count-label'))).data,
      'Showing 12 of 12',
    );
  });

  testWidgets('filtering does not disturb an active sort', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('header-salary')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('filter-field')), 'sales');
    await tester.pump();
    expectOrder(tester, ['Owen Whitfield', 'Aicha Benali', 'Grace Okafor']);
    await tester.enterText(find.byKey(const Key('filter-field')), '');
    await tester.pump();
    expectOrder(tester, ['Marta Kowalska', 'Lars Nyström', 'Owen Whitfield']);
  });
}
