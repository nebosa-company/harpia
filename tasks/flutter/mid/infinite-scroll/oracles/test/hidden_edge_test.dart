import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:infinite_scroll/item_list_screen.dart';
import 'package:infinite_scroll/item_repository.dart';
import 'package:infinite_scroll/main.dart';

/// Repository whose pages complete only when the test says so.
class ManualRepository implements ItemRepository {
  final List<int> calls = [];
  final Map<int, Completer<List<String>>> pending = {};

  @override
  Future<List<String>> fetchPage(int page) {
    calls.add(page);
    final completer = Completer<List<String>>();
    pending[page] = completer;
    return completer.future;
  }
}

void main() {
  test('DemoItemRepository serves 95 items in pages of 20', () async {
    final repo = DemoItemRepository(delay: Duration.zero);
    final page0 = await repo.fetchPage(0);
    expect(page0.length, 20);
    expect(page0.first, 'Item 1');
    expect(page0.last, 'Item 20');
    final page4 = await repo.fetchPage(4);
    expect(page4.length, 15);
    expect(page4.first, 'Item 81');
    expect(page4.last, 'Item 95');
    expect(await repo.fetchPage(5), isEmpty);
    expect(await repo.fetchPage(6), isEmpty);
  });

  testWidgets('spinner shows while pending and requests never overlap', (tester) async {
    final repo = ManualRepository();
    await tester.pumpWidget(MaterialApp(home: ItemListScreen(repository: repo)));
    await tester.pump();
    expect(find.byKey(const Key('loading-indicator')), findsOneWidget);
    expect(repo.calls, [0]);

    repo.pending[0]!.complete([for (var i = 1; i <= 5; i++) 'Short $i']);
    await tester.pump();
    await tester.pump();
    // Five short rows leave the sentinel visible, so page 1 gets requested.
    expect(find.text('Short 1'), findsOneWidget);
    expect(repo.calls, [0, 1]);
    expect(find.byKey(const Key('loading-indicator')), findsOneWidget);

    // While page 1 is in flight, further frames and drags must not re-request.
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(repo.calls, [0, 1]);

    repo.pending[1]!.complete(const []);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('end-of-list')), findsOneWidget);
    expect(find.byKey(const Key('loading-indicator')), findsNothing);
    expect(repo.calls, [0, 1]);
  });

  testWidgets('ItemsApp wires the demo repository', (tester) async {
    await tester.pumpWidget(const ItemsApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('Item 1'), findsOneWidget);
  });
}
