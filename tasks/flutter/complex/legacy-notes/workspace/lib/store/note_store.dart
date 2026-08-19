import 'package:flutter/foundation.dart';

import '../models/note.dart';

/// Holds the notes and tells listeners when things change.
class NoteStore extends ChangeNotifier {
  final List<Note> _notes = [
    Note(id: 1, title: 'Creek water levels', body: 'Down 12cm since May.'),
    Note(id: 2, title: 'Ridge survey', body: 'Two new trails on the north face.'),
    Note(id: 3, title: 'Owl census', body: 'Heard four, saw one.'),
    Note(id: 4, title: 'Fence repairs', body: 'East gate hinge needs a bolt.'),
  ];

  List<Note> get notes => List.unmodifiable(_notes);

  Note byId(int id) => _notes.firstWhere((note) => note.id == id);

  void update(int id, {required String title, required String body}) {
    final note = byId(id);
    note.title = title;
    note.body = body;
    // Screens listen to this store, so they will pick the change up.
  }

  void delete(int id) {
    _notes.removeAt(id);
    notifyListeners();
  }
}
