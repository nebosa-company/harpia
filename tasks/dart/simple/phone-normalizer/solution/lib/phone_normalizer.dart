/// US phone number normalization.

/// Returns the E.164 form of a US number, or null when invalid.
String? normalizeUsPhone(String raw) {
  final digits = StringBuffer();
  var plus = false;
  for (var i = 0; i < raw.length; i++) {
    final ch = raw[i];
    final code = ch.codeUnitAt(0);
    if (ch == '+') {
      if (plus || digits.isNotEmpty) return null;
      plus = true;
    } else if (code >= 48 && code <= 57) {
      digits.write(ch);
    } else if (ch == ' ' || ch == '.' || ch == '-' || ch == '(' || ch == ')') {
      // separator, ignored
    } else {
      return null;
    }
  }
  var d = digits.toString();
  if (plus) {
    if (!d.startsWith('1')) return null;
    d = d.substring(1);
  } else if (d.length == 11 && d.startsWith('1')) {
    d = d.substring(1);
  }
  if (d.length != 10) return null;
  bool badLead(String c) => c == '0' || c == '1';
  if (badLead(d[0]) || badLead(d[3])) return null;
  return '+1$d';
}
