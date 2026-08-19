import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:currency_input/currency_input_formatter.dart';
import 'package:currency_input/main.dart';

TextEditingValue value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

void main() {
  test('more than 12 digits keeps the previous value', () {
    final formatter = CurrencyInputFormatter();
    final out = formatter.formatEditUpdate(
      value('1,234,567,890.12'),
      value('1234567890123'),
    );
    expect(out.text, '1,234,567,890.12');
  });

  testWidgets('field formats while typing and preview mirrors it', (tester) async {
    await tester.pumpWidget(const CurrencyApp());
    await tester.enterText(find.byKey(const Key('amount-field')), '4242424242');
    await tester.pump();
    final field = tester.widget<TextField>(find.byKey(const Key('amount-field')));
    expect(field.controller?.text, '42,424,242.42');
    final preview = tester.widget<Text>(find.byKey(const Key('amount-preview')));
    expect(preview.data, r'$42,424,242.42');
  });

  testWidgets('empty field previews as zero dollars', (tester) async {
    await tester.pumpWidget(const CurrencyApp());
    final preview = tester.widget<Text>(find.byKey(const Key('amount-preview')));
    expect(preview.data, r'$0.00');
    await tester.enterText(find.byKey(const Key('amount-field')), '5');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('amount-preview'))).data,
      r'$0.05',
    );
    await tester.enterText(find.byKey(const Key('amount-field')), '');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('amount-preview'))).data,
      r'$0.00',
    );
  });
}
