/// Caesar cipher over ASCII letters.

/// Rotates letters forward by [shift]; see the brief for exact rules.
String encode(String text, int shift) => _rotate(text, shift);

/// Inverse of [encode].
String decode(String text, int shift) => _rotate(text, -shift);

String _rotate(String text, int shift) {
  final s = ((shift % 26) + 26) % 26;
  final out = text.codeUnits.map((c) {
    if (c >= 65 && c <= 90) return 65 + (c - 65 + s) % 26;
    if (c >= 97 && c <= 122) return 97 + (c - 97 + s) % 26;
    return c;
  }).toList();
  return String.fromCharCodes(out);
}
