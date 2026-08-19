import 'package:flutter/services.dart';

/// Formats typed digits as a cents-first currency amount.
class CurrencyInputFormatter extends TextInputFormatter {
  static const int maxDigits = 12;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxDigits) {
      return oldValue;
    }
    final formatted = formatCents(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// '123456' -> '1,234.56'; '' -> ''.
  static String formatCents(String digits) {
    if (digits.isEmpty) {
      return '';
    }
    final cents = digits.replaceFirst(RegExp(r'^0+'), '');
    final padded = cents.padLeft(3, '0');
    final whole = padded.substring(0, padded.length - 2);
    final fraction = padded.substring(padded.length - 2);
    final grouped = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) {
        grouped.write(',');
      }
      grouped.write(whole[i]);
    }
    return '$grouped.$fraction';
  }
}
