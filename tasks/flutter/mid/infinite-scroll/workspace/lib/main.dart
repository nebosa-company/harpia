import 'package:flutter/material.dart';

void main() => runApp(const ItemsApp());

/// Placeholder — the paged list still needs to be built.
class ItemsApp extends StatelessWidget {
  const ItemsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Catalog',
      home: Scaffold(
        body: Center(child: Text('Catalog loading experience TBD')),
      ),
    );
  }
}
