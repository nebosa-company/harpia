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

  /// Active notes, in id order.
  List<Note> get notes =>
      List.unmodifiable(_notes.where((note) => !note.archived));

  /// Archived notes, in id order.
  List<Note> get archivedNotes =>
      List.unmodifiable(_notes.where((note) => note.archived));

  Note byId(int id) => _notes.firstWhere((note) => note.id == id);

  Note? byIdOrNull(int id) {
    for (final note in _notes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  void update(int id, {required String title, required String body}) {
    final note = byId(id);
    note.title = title;
    note.body = body;
    notifyListeners();
  }

  void delete(int id) {
    _notes.removeWhere((note) => note.id == id);
    notifyListeners();
  }

  void archive(int id) {
    byId(id).archived = true;
    notifyListeners();
  }

  void restore(int id) {
    byId(id).archived = false;
    notifyListeners();
  }
}
