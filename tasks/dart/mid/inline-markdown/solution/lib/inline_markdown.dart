/// Inline markdown to HTML.

final String _mark = String.fromCharCode(0);
final String _bs = String.fromCharCode(92); // backslash

// Escape pass: a backslash followed by one of \ ` * [ ] ( ).
final RegExp _escapeRe =
    RegExp(_bs + _bs + '([' + _bs + _bs + '`*' + _bs + '[' + _bs + ']()])');
final RegExp _codeRe = RegExp(r'`([^`]+)`');
final RegExp _linkRe = RegExp(r'\[([^\[\]]*)\]\(([^()\s]*)\)');
final RegExp _boldRe = RegExp(r'\*\*(\S|\S[\s\S]*?\S)\*\*');
final RegExp _italicRe = RegExp(r'\*(\S|\S[\s\S]*?\S)\*');
final RegExp _tokenRe = RegExp(_mark + r'(\d+)' + _mark);

String _escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _escapeAttr(String s) => _escapeHtml(s).replaceAll('"', '&quot;');

/// Renders one line of inline markdown; see the brief for the pass pipeline.
String renderInline(String text) {
  final shielded = <String>[];
  String shield(String html) {
    shielded.add(html);
    return '$_mark${shielded.length - 1}$_mark';
  }

  String italicPass(String s) => s.replaceAllMapped(
      _italicRe, (m) => shield('<em>${_escapeHtml(m[1]!)}</em>'));

  String boldItalicPass(String s) {
    s = s.replaceAllMapped(_boldRe,
        (m) => shield('<strong>${_escapeHtml(italicPass(m[1]!))}</strong>'));
    return italicPass(s);
  }

  var s = text;
  // 1. Backslash escapes.
  s = s.replaceAllMapped(_escapeRe, (m) => shield(_escapeHtml(m[1]!)));
  // 2. Code spans.
  s = s.replaceAllMapped(
      _codeRe, (m) => shield('<code>${_escapeHtml(m[1]!)}</code>'));
  // 3. Links (label gets bold/italic processing; url is attribute-escaped).
  s = s.replaceAllMapped(_linkRe, (m) {
    final label = boldItalicPass(m[1]!);
    return shield('<a href="${_escapeAttr(m[2]!)}">${_escapeHtml(label)}</a>');
  });
  // 4 + 5. Bold, then italic.
  s = boldItalicPass(s);
  // 6. Escape the remaining literal text.
  s = _escapeHtml(s);
  // Resolve shielded spans (they may nest).
  String unshield(String value) => value.replaceAllMapped(
      _tokenRe, (m) => unshield(shielded[int.parse(m[1]!)]));
  return unshield(s);
}
