import 'package:flutter/material.dart';

void main() => runApp(const SignupApp());

/// Placeholder — the signup form still needs to be built.
class SignupApp extends StatelessWidget {
  const SignupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Signup',
      home: Scaffold(
        body: Center(child: Text('Form goes here')),
      ),
    );
  }
}
