import 'package:flutter/material.dart';

/// Three-column kanban board with immediate drag-and-drop.
class KanbanBoard extends StatefulWidget {
  const KanbanBoard({this.initial, super.key});

  final Map<String, List<String>>? initial;

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  static const columns = ['To Do', 'In Progress', 'Done'];
  static const slugs = {
    'To Do': 'todo',
    'In Progress': 'inprogress',
    'Done': 'done',
  };

  late final Map<String, List<String>> _cards;
  final TextEditingController _newCard = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cards = {
      for (final column in columns)
        column: List<String>.from(widget.initial?[column] ?? const []),
    };
  }

  @override
  void dispose() {
    _newCard.dispose();
    super.dispose();
  }

  void _move(String title, String target) {
    final source = _cards.entries
        .firstWhere((entry) => entry.value.contains(title))
        .key;
    if (source == target) {
      return;
    }
    setState(() {
      _cards[source]!.remove(title);
      _cards[target]!.add(title);
    });
  }

  void _add() {
    final title = _newCard.text.trim();
    if (title.isEmpty) {
      return;
    }
    setState(() {
      _cards['To Do']!.add(title);
      _newCard.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final column in columns)
          Expanded(child: _buildColumn(context, column)),
      ],
    );
  }

  Widget _buildColumn(BuildContext context, String column) {
    final slug = slugs[column]!;
    final cards = _cards[column]!;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(column, style: Theme.of(context).textTheme.titleMedium),
              CircleAvatar(
                radius: 12,
                child: Text(
                  '${cards.length}',
                  key: Key('count-$slug'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DragTarget<String>(
              onAcceptWithDetails: (details) => _move(details.data, column),
              builder: (context, candidates, rejected) {
                return Container(
                  key: Key('column-$slug'),
                  decoration: BoxDecoration(
                    color: candidates.isEmpty
                        ? Colors.blueGrey.shade50
                        : Colors.blueGrey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final title in cards) _buildCard(title),
                    ],
                  ),
                );
              },
            ),
          ),
          if (column == 'To Do')
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('new-card-field'),
                    controller: _newCard,
                    decoration: const InputDecoration(hintText: 'New card'),
                  ),
                ),
                IconButton(
                  key: const Key('add-card-button'),
                  icon: const Icon(Icons.add),
                  onPressed: _add,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCard(String title) {
    final tile = Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(title),
      ),
    );
    return Draggable<String>(
      key: Key('card-$title'),
      data: title,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 200, child: tile),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
    );
  }
}
