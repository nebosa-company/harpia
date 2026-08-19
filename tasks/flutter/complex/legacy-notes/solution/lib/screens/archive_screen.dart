import 'package:flutter/material.dart';

import '../store/note_store.dart';

/// Archived notes with per-row restore.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({required this.store, super.key});

  final NoteStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final archived = store.archivedNotes;
          if (archived.isEmpty) {
            return const Center(
              child: Text('Archive is empty', key: Key('archive-empty')),
            );
          }
          return ListView(
            children: [
              for (final note in archived)
                ListTile(
                  key: Key('archived-${note.id}'),
                  title: Text(note.title),
                  trailing: TextButton(
                    key: Key('restore-${note.id}'),
                    onPressed: () => store.restore(note.id),
                    child: const Text('Restore'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
