import 'dart:async';

import 'package:flutter/material.dart';

import 'connectivity_banner.dart';

void main() => runApp(const ConnectivityDemoApp());

class ConnectivityDemoApp extends StatefulWidget {
  const ConnectivityDemoApp({super.key});

  @override
  State<ConnectivityDemoApp> createState() => _ConnectivityDemoAppState();
}

class _ConnectivityDemoAppState extends State<ConnectivityDemoApp> {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _nextEmitsOffline = true;

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  void _toggle() {
    _controller.add(!_nextEmitsOffline ? true : false);
    setState(() {
      _nextEmitsOffline = !_nextEmitsOffline;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Field app',
      home: Scaffold(
        appBar: AppBar(title: const Text('Field app')),
        body: ConnectivityBanner(
          status: _controller.stream,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Survey form goes here'),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('toggle-connectivity'),
                  onPressed: _toggle,
                  child: Text(
                    _nextEmitsOffline ? 'Simulate offline' : 'Simulate online',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
