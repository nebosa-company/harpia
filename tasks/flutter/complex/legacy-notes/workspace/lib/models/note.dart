/// One field note.
class Note {
  Note({
    required this.id,
    required this.title,
    required this.body,
    this.archived = false,
  });

  final int id;
  String title;
  String body;
  bool archived;
}
