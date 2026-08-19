import 'package:flutter/material.dart';

import 'search_api.dart';
import 'search_screen.dart';

void main() => runApp(const SearchApp());

class SearchApp extends StatelessWidget {
  const SearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pantry search',
      home: Scaffold(
        appBar: AppBar(title: const Text('Pantry search')),
        body: SearchScreen(api: DemoSearchApi()),
      ),
    );
  }
}
