import 'package:flutter/material.dart';

import 'item_list_screen.dart';
import 'item_repository.dart';

void main() => runApp(const ItemsApp());

class ItemsApp extends StatelessWidget {
  const ItemsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catalog',
      home: ItemListScreen(repository: DemoItemRepository()),
    );
  }
}
