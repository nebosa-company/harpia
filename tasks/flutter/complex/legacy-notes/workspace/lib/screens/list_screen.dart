import 'package:flutter/material.dart';

import '../store/note_store.dart';
import 'detail_screen.dart';

/// The main list of notes.
class ListScreen extends StatefulWidget {
  const ListScreen({required this.store, super.key});

  final NoteStore store;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  // Remembers which tile the user last picked.
  int _selectedIndex = 0;

  void _openSelected(BuildContext context) {
    final note = widget.store.notes[_selectedIndex];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(store: widget.store, noteId: note.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field notes')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final notes = widget.store.notes;
          return ListView(
            children: [
              for (final note in notes)
                ListTile(
                  key: Key('note-${note.id}'),
                  title: Text(note.title),
                  subtitle: Text(
                    note.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _openSelected(context),
                ),
            ],
          );
        },
      ),
    );
  }
}
