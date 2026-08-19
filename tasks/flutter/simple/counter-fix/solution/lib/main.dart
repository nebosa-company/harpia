import 'package:flutter/material.dart';

void main() => runApp(const CounterApp());

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Tally',
      home: CounterPage(),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int _count = 0;

  void _increment() {
    setState(() {
      _count++;
    });
  }

  void _decrement() {
    setState(() {
      if (_count > 0) {
        _count--;
      }
    });
  }

  void _reset() {
    setState(() {
      _count = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tally')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Current tally'),
            Text(
              '$_count',
              key: const Key('count-label'),
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const Key('decrement'),
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _decrement,
                ),
                const SizedBox(width: 24),
                IconButton(
                  key: const Key('increment'),
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _increment,
                ),
              ],
            ),
            TextButton(
              key: const Key('reset'),
              onPressed: _reset,
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }
}
