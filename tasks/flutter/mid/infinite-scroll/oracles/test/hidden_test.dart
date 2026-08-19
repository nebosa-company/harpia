import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:infinite_scroll/item_list_screen.dart';
import 'package:infinite_scroll/item_repository.dart';

/// Repository that resolves immediately and records every requested page.
class ScriptedRepository implements ItemRepository {
  ScriptedRepository(this.pages);

  final List<List<String>> pages;
  final List<int> calls = [];

  @override
  Future<List<String>> fetchPage(int page) async {
    calls.add(page);
    if (page >= pages.length) {
      return const [];
    }
    return pages[page];
  }
}

List<List<String>> threePages() => [
      [for (var i = 1; i <= 30; i++) 'Row $i'],
      [for (var i = 31; i <= 60; i++) 'Row $i'],
      [for (var i = 61; i <= 72; i++) 'Row $i'],
    ];

Widget host(ItemRepository repo) => MaterialApp(
      home: ItemListScreen(repository: repo),
    );

void main() {
  testWidgets('loads page 0 immediately and only page 0', (tester) async {
    final repo = ScriptedRepository(threePages());
    await tester.pumpWidget(host(repo));
    await tester.pumpAndSettle();
    expect(repo.calls, [0]);
    expect(find.text('Row 1'), findsOneWidget);
    expect(find.text('Row 31'), findsNothing);
  });

  testWidgets('scrolling to the sentinel pages through to the end', (tester) async {
    final repo = ScriptedRepository(threePages());
    await tester.pumpWidget(host(repo));
    await tester.pumpAndSettle();

    var guard = 0;
    while (find.byKey(const Key('end-of-list')).evaluate().isEmpty &&
        guard < 40) {
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      guard++;
    }

    expect(find.byKey(const Key('end-of-list')), findsOneWidget);
    expect(find.text('End of list'), findsOneWidget);
    expect(find.byKey(const Key('loading-indicator')), findsNothing);
    expect(find.text('Row 72'), findsOneWidget);
    expect(repo.calls, [0, 1, 2, 3],
        reason: 'each page requested exactly once, in order');

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(repo.calls, [0, 1, 2, 3],
        reason: 'no further requests after exhaustion');
  });
}
