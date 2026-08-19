import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:debounced_search/search_api.dart';
import 'package:debounced_search/search_screen.dart';

/// API whose responses complete only when the test releases them.
class ManualApi implements SearchApi {
  final List<String> calls = [];
  final Map<String, Completer<List<String>>> pending = {};

  @override
  Future<List<String>> search(String query) {
    calls.add(query);
    final completer = Completer<List<String>>();
    pending[query] = completer;
    return completer.future;
  }
}

void main() {
  test('DemoSearchApi filters the catalog case-insensitively', () async {
    final api = DemoSearchApi(delay: Duration.zero);
    expect(await api.search('ap'), ['apple', 'apricot', 'grape']);
    expect(await api.search('AP'), ['apple', 'apricot', 'grape']);
    expect(await api.search('berry'), ['blueberry']);
    expect(await api.search('zz'), isEmpty);
  });

  testWidgets('spinner shows while the call is in flight', (tester) async {
    final api = ManualApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SearchScreen(api: api)),
    ));
    expect(find.byKey(const Key('search-loading')), findsNothing);
    await tester.enterText(find.byKey(const Key('search-field')), 'pea');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(api.calls, ['pea']);
    expect(find.byKey(const Key('search-loading')), findsOneWidget);
    api.pending['pea']!.complete(['pear', 'peach']);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('search-loading')), findsNothing);
    expect(find.text('pear'), findsOneWidget);
    expect(find.text('peach'), findsOneWidget);
  });

  testWidgets('a stale response never overwrites a newer one', (tester) async {
    final api = ManualApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SearchScreen(api: api)),
    ));
    await tester.enterText(find.byKey(const Key('search-field')), 'first');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('search-field')), 'second');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(api.calls, ['first', 'second']);

    api.pending['second']!.complete(['second-hit']);
    await tester.pump();
    await tester.pump();
    expect(find.text('second-hit'), findsOneWidget);

    api.pending['first']!.complete(['first-hit']);
    await tester.pump();
    await tester.pump();
    expect(find.text('second-hit'), findsOneWidget,
        reason: 'late completion of an older query must be dropped');
    expect(find.text('first-hit'), findsNothing);
  });

  testWidgets('custom debounce duration is honored', (tester) async {
    final api = ManualApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchScreen(
          api: api,
          debounce: const Duration(milliseconds: 600),
        ),
      ),
    ));
    await tester.enterText(find.byKey(const Key('search-field')), 'plu');
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(api.calls, ['plu']);
    api.pending['plu']!.complete(['plum']);
    await tester.pump();
  });
}
