import 'package:flutter/material.dart';

import 'screens/list_screen.dart';
import 'store/note_store.dart';

void main() => runApp(FieldNotesApp());

class FieldNotesApp extends StatelessWidget {
  FieldNotesApp({super.key});

  final NoteStore _store = NoteStore();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Field notes',
      home: ListScreen(store: _store),
    );
  }
}
