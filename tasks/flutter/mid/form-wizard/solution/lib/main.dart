import 'package:flutter/material.dart';

void main() => runApp(const WizardApp());

class WizardApp extends StatelessWidget {
  const WizardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Signup',
      home: Scaffold(body: SafeArea(child: SignupWizard())),
    );
  }
}

class SignupWizard extends StatefulWidget {
  const SignupWizard({super.key});

  @override
  State<SignupWizard> createState() => _SignupWizardState();
}

class _SignupWizardState extends State<SignupWizard> {
  int _step = 0;
  bool _submitted = false;

  final _accountFormKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _street.dispose();
    _city.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && !_accountFormKey.currentState!.validate()) {
      return;
    }
    if (_step == 1 && !_addressFormKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _step++;
    });
  }

  void _back() {
    setState(() {
      _step--;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return const Center(
        child: Text('All set!', key: Key('wizard-success')),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Step ${_step + 1} of 3',
            key: const Key('step-indicator'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Expanded(child: _stepBody()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_step > 0)
                OutlinedButton(
                  key: const Key('back-button'),
                  onPressed: _back,
                  child: const Text('Back'),
                )
              else
                const SizedBox.shrink(),
              if (_step < 2)
                ElevatedButton(
                  key: const Key('next-button'),
                  onPressed: _next,
                  child: const Text('Next'),
                )
              else
                ElevatedButton(
                  key: const Key('submit-button'),
                  onPressed: () {
                    setState(() {
                      _submitted = true;
                    });
                  },
                  child: const Text('Submit'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return Form(
          key: _accountFormKey,
          child: Column(
            children: [
              TextFormField(
                key: const Key('name-field'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Name is required' : null,
              ),
              TextFormField(
                key: const Key('email-field'),
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final v = value ?? '';
                  return v.contains('@') && v.contains('.')
                      ? null
                      : 'Enter a valid email';
                },
              ),
            ],
          ),
        );
      case 1:
        return Form(
          key: _addressFormKey,
          child: Column(
            children: [
              TextFormField(
                key: const Key('street-field'),
                controller: _street,
                decoration: const InputDecoration(labelText: 'Street'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Street is required' : null,
              ),
              TextFormField(
                key: const Key('city-field'),
                controller: _city,
                decoration: const InputDecoration(labelText: 'City'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'City is required' : null,
              ),
            ],
          ),
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Review your details'),
            const SizedBox(height: 12),
            Text(_name.text, key: const Key('review-name')),
            Text(_email.text, key: const Key('review-email')),
            Text(_street.text, key: const Key('review-street')),
            Text(_city.text, key: const Key('review-city')),
          ],
        );
    }
  }
}
