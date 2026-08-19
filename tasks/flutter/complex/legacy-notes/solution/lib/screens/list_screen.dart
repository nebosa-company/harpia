import 'package:flutter/material.dart';

import '../store/note_store.dart';
import 'archive_screen.dart';
import 'detail_screen.dart';

/// The main list of notes.
class ListScreen extends StatefulWidget {
  const ListScreen({required this.store, super.key});

  final NoteStore store;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  void _open(BuildContext context, int noteId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(store: widget.store, noteId: noteId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field notes'),
        actions: [
          IconButton(
            key: const Key('open-archive'),
            icon: const Icon(Icons.archive_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ArchiveScreen(store: widget.store),
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final notes = widget.store.notes;
          return ListView(
            children: [
              for (final note in notes)
                Dismissible(
                  key: Key('note-${note.id}'),
                  onDismissed: (_) => widget.store.archive(note.id),
                  background: Container(color: Colors.amber.shade200),
                  child: ListTile(
                    title: Text(note.title),
                    subtitle: Text(
                      note.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _open(context, note.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
