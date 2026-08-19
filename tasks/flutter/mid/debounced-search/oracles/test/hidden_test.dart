import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:debounced_search/search_api.dart';
import 'package:debounced_search/search_screen.dart';

/// Recording API that resolves immediately.
class RecordingApi implements SearchApi {
  final List<String> calls = [];

  @override
  Future<List<String>> search(String query) async {
    calls.add(query);
    if (query == 'none') {
      return const [];
    }
    return ['$query-1', '$query-2'];
  }
}

Widget host(SearchApi api, {Duration? debounce}) => MaterialApp(
      home: Scaffold(
        body: SearchScreen(
          api: api,
          debounce: debounce ?? const Duration(milliseconds: 300),
        ),
      ),
    );

void main() {
  testWidgets('rapid typing produces one call with the latest text', (tester) async {
    final api = RecordingApi();
    await tester.pumpWidget(host(api));
    await tester.enterText(find.byKey(const Key('search-field')), 'a');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byKey(const Key('search-field')), 'ap');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byKey(const Key('search-field')), 'app');
    expect(api.calls, isEmpty, reason: 'debounce window still open');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(api.calls, ['app']);
    expect(find.text('app-1'), findsOneWidget);
    expect(find.text('app-2'), findsOneWidget);
  });

  testWidgets('no call before the debounce elapses', (tester) async {
    final api = RecordingApi();
    await tester.pumpWidget(host(api));
    await tester.enterText(find.byKey(const Key('search-field')), 'pe');
    await tester.pump(const Duration(milliseconds: 299));
    expect(api.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();
    expect(api.calls, ['pe']);
  });

  testWidgets('empty query clears results without calling the api', (tester) async {
    final api = RecordingApi();
    await tester.pumpWidget(host(api));
    await tester.enterText(find.byKey(const Key('search-field')), 'pe');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('pe-1'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search-field')), '');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(api.calls, ['pe'], reason: 'empty string must not be searched');
    expect(find.text('pe-1'), findsNothing);
  });

  testWidgets('empty result set shows No results', (tester) async {
    final api = RecordingApi();
    await tester.pumpWidget(host(api));
    await tester.enterText(find.byKey(const Key('search-field')), 'none');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byKey(const Key('no-results')), findsOneWidget);
    expect(find.text('No results'), findsOneWidget);
  });
}
