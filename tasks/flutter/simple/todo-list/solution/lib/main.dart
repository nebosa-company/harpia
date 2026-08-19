import 'package:flutter/material.dart';

void main() => runApp(const TodoApp());

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Todos',
      home: TodoPage(),
    );
  }
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final List<String> _items = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      if (!_items.contains(text)) {
        _items.add(text);
      }
      _controller.clear();
    });
  }

  void _remove(String text) {
    setState(() {
      _items.remove(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('todo-input'),
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'What needs doing?',
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('todo-add'),
                  icon: const Icon(Icons.add),
                  onPressed: _add,
                ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('Nothing to do', key: Key('empty-state')),
                  )
                : ListView(
                    children: [
                      for (final item in _items)
                        ListTile(
                          title: Text(item),
                          trailing: IconButton(
                            key: Key('remove-$item'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _remove(item),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
