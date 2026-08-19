import 'package:flutter/material.dart';

import '../store/note_store.dart';

/// Edit a note's title and body.
class EditScreen extends StatefulWidget {
  const EditScreen({required this.store, required this.noteId, super.key});

  final NoteStore store;
  final int noteId;

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;

  @override
  void initState() {
    super.initState();
    final note = widget.store.byId(widget.noteId);
    _title = TextEditingController(text: note.title);
    _body = TextEditingController(text: note.body);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _save() {
    widget.store.update(
      widget.noteId,
      title: _title.text,
      body: _body.text,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit note')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              key: const Key('edit-title-field'),
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              key: const Key('edit-body-field'),
              controller: _body,
              decoration: const InputDecoration(labelText: 'Body'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('save-button'),
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
