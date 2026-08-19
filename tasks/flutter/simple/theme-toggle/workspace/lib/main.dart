import 'package:flutter/material.dart';

void main() => runApp(const ThemeToggleApp());

class ThemeToggleApp extends StatefulWidget {
  const ThemeToggleApp({super.key});

  @override
  State<ThemeToggleApp> createState() => _ThemeToggleAppState();
}

class _ThemeToggleAppState extends State<ThemeToggleApp> {
  bool _dark = false;

  void _setDark(bool value) {
    setState(() {
      _dark = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mood light',
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.indigo,
      ),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(dark: _dark, onChanged: _setDark),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({required this.dark, required this.onChanged, super.key});

  final bool dark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood light'),
        actions: [
          Switch(
            key: const Key('theme-switch'),
            value: dark,
            onChanged: onChanged,
          ),
        ],
      ),
      body: Center(
        child: Text(
          brightness == Brightness.dark ? 'Dark mode' : 'Light mode',
          key: const Key('mode-label'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
