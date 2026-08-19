import 'package:flutter/material.dart';

import '../store/note_store.dart';
import 'edit_screen.dart';

/// Full view of one note.
class DetailScreen extends StatelessWidget {
  const DetailScreen({required this.store, required this.noteId, super.key});

  final NoteStore store;
  final int noteId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final note = store.byId(noteId);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Note'),
            actions: [
              IconButton(
                key: const Key('edit-button'),
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          EditScreen(store: store, noteId: noteId),
                    ),
                  );
                },
              ),
              IconButton(
                key: const Key('delete-button'),
                icon: const Icon(Icons.delete),
                onPressed: () {
                  store.delete(noteId);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  key: const Key('detail-title'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(note.body, key: const Key('detail-body')),
              ],
            ),
          ),
        );
      },
    );
  }
}
