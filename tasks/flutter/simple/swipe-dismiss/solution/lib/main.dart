import 'package:flutter/material.dart';

void main() => runApp(const ChoresApp());

class ChoresApp extends StatelessWidget {
  const ChoresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Chores',
      home: ChoresPage(),
    );
  }
}

class ChoresPage extends StatefulWidget {
  const ChoresPage({super.key});

  @override
  State<ChoresPage> createState() => _ChoresPageState();
}

class _ChoresPageState extends State<ChoresPage> {
  final List<String> _chores = [
    'Water plants',
    'Take out trash',
    'Feed the cat',
    'Vacuum hall',
  ];

  void _remove(String name) {
    setState(() {
      _chores.remove(name);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed $name'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chores')),
      body: _chores.isEmpty
          ? const Center(
              child: Text('All chores done!', key: Key('all-done')),
            )
          : ListView(
              children: [
                for (final name in _chores)
                  Dismissible(
                    key: Key('chore-$name'),
                    onDismissed: (_) => _remove(name),
                    background: Container(color: Colors.red),
                    child: ListTile(title: Text(name)),
                  ),
              ],
            ),
    );
  }
}
