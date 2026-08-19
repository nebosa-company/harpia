import 'package:flutter/material.dart';

import 'validators.dart';

void main() => runApp(const SignupApp());

class SignupApp extends StatelessWidget {
  const SignupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Signup',
      home: SignupPage(),
    );
  }
}

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;

  void _submit() {
    setState(() {
      _submitted = _formKey.currentState!.validate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                key: const Key('username-field'),
                decoration: const InputDecoration(labelText: 'Username'),
                validator: validateUsername,
              ),
              TextFormField(
                key: const Key('email-field'),
                decoration: const InputDecoration(labelText: 'Email'),
                validator: validateEmail,
              ),
              TextFormField(
                key: const Key('password-field'),
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: validatePassword,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('submit-button'),
                onPressed: _submit,
                child: const Text('Sign up'),
              ),
              if (_submitted)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Account created', key: Key('signup-success')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
