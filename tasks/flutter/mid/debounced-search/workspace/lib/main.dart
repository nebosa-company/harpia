import 'package:flutter/material.dart';

void main() => runApp(const SearchApp());

/// Placeholder — the search experience still needs to be built.
class SearchApp extends StatelessWidget {
  const SearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Pantry search',
      home: Scaffold(
        body: Center(child: Text('Search is on the roadmap')),
      ),
    );
  }
}
