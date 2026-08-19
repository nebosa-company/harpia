import 'package:flutter/material.dart';

import 'expansion_card.dart';

void main() => runApp(const CardsApp());

class CardsApp extends StatelessWidget {
  const CardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cards',
      home: Scaffold(
        appBar: AppBar(title: const Text('Order')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: const [
            ExpansionCard(
              title: 'Shipping details',
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Standard delivery, 3-5 business days.\n'
                  'Tracking is emailed on dispatch.',
                ),
              ),
            ),
            ExpansionCard(
              title: 'Payment methods',
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Cards and bank transfer accepted.\n'
                  'Invoices are issued at dispatch.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
