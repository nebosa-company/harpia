import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:currency_input/currency_input_formatter.dart';

TextEditingValue value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

String format(String oldText, String newText) {
  final formatter = CurrencyInputFormatter();
  return formatter.formatEditUpdate(value(oldText), value(newText)).text;
}

void main() {
  test('digits fill cents first', () {
    expect(format('', '1'), '0.01');
    expect(format('0.01', '0.012'), '0.12');
    expect(format('0.12', '0.123'), '1.23');
  });

  test('thousands are comma separated', () {
    expect(format('', '123456'), '1,234.56');
    expect(format('', '1234567'), '12,345.67');
    expect(format('', '123456789012'), '1,234,567,890.12');
  });

  test('non-digits are ignored', () {
    expect(format('', 'abc'), '');
    expect(format('', '12a3'), '1.23');
    expect(format('', r'$1,2.34'), '12.34');
  });

  test('leading zeros collapse', () {
    expect(format('', '000123'), '1.23');
    expect(format('', '0'), '0.00');
    expect(format('', '00'), '0.00');
  });

  test('empty input formats to empty string', () {
    expect(format('1.23', ''), '');
  });

  test('caret lands at the end', () {
    final formatter = CurrencyInputFormatter();
    final out = formatter.formatEditUpdate(value(''), value('123456'));
    expect(out.selection.baseOffset, out.text.length);
    expect(out.selection.extentOffset, out.text.length);
  });
}
