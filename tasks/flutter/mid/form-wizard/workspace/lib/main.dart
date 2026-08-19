import 'package:flutter/material.dart';

void main() => runApp(const WizardApp());

/// Placeholder — the wizard still needs to be built.
class WizardApp extends StatelessWidget {
  const WizardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Signup',
      home: Scaffold(
        body: Center(child: Text('Wizard? What wizard?')),
      ),
    );
  }
}
