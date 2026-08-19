/// Mustache-subset template rendering.

sealed class _Node {}

class _Text extends _Node {
  final String text;

  _Text(this.text);
}

class _Interpolation extends _Node {
  final String name;
  final bool escape;

  _Interpolation(this.name, this.escape);
}

class _Section extends _Node {
  final String name;
  final bool inverted;
  final List<_Node> body;

  _Section(this.name, this.inverted, this.body);
}

/// Renders [template] against [context]; see the brief for the tag set.
String render(String template, Map<String, Object?> context) {
  final nodes = _parse(template);
  final out = StringBuffer();
  _renderNodes(nodes, <Object?>[context], out);
  return out.toString();
}

List<_Node> _parse(String template) {
  final root = <_Node>[];
  final bodies = <List<_Node>>[root];
  final open = <String>[];
  var i = 0;
  while (i < template.length) {
    final start = template.indexOf('{{', i);
    if (start < 0) {
      if (i < template.length) {
        bodies.last.add(_Text(template.substring(i)));
      }
      break;
    }
    if (start > i) bodies.last.add(_Text(template.substring(i, start)));
    if (template.startsWith('{{{', start)) {
      final end = template.indexOf('}}}', start + 3);
      if (end < 0) throw FormatException('unclosed {{{ tag');
      final name = template.substring(start + 3, end).trim();
      if (name.isEmpty) throw FormatException('empty tag name');
      bodies.last.add(_Interpolation(name, false));
      i = end + 3;
      continue;
    }
    final end = template.indexOf('}}', start + 2);
    if (end < 0) throw FormatException('unclosed {{ tag');
    final raw = template.substring(start + 2, end);
    i = end + 2;
    final content = raw.trim();
    if (content.startsWith('!')) {
      continue; // comment
    }
    if (content.startsWith('#') || content.startsWith('^')) {
      final name = content.substring(1).trim();
      if (name.isEmpty) throw FormatException('empty section name');
      final section = _Section(name, content.startsWith('^'), <_Node>[]);
      bodies.last.add(section);
      bodies.add(section.body);
      open.add(name);
      continue;
    }
    if (content.startsWith('/')) {
      final name = content.substring(1).trim();
      if (name.isEmpty) throw FormatException('empty closing name');
      if (open.isEmpty) {
        throw FormatException('closing tag without open section: $name');
      }
      if (open.last != name) {
        throw FormatException(
            'mismatched closing tag: expected ${open.last}, got $name');
      }
      open.removeLast();
      bodies.removeLast();
      continue;
    }
    if (content.isEmpty) throw FormatException('empty tag name');
    bodies.last.add(_Interpolation(content, true));
  }
  if (open.isNotEmpty) {
    throw FormatException('unclosed section: ${open.last}');
  }
  return root;
}

Object? _lookup(List<Object?> stack, String name) {
  if (name == '.') return stack.last;
  final parts = name.split('.');
  Object? current;
  var found = false;
  for (var i = stack.length - 1; i >= 0; i--) {
    final frame = stack[i];
    if (frame is Map && frame.containsKey(parts[0])) {
      current = frame[parts[0]];
      found = true;
      break;
    }
  }
  if (!found) return _unresolved;
  for (var i = 1; i < parts.length; i++) {
    final value = current;
    if (value is Map && value.containsKey(parts[i])) {
      current = value[parts[i]];
    } else {
      return _unresolved;
    }
  }
  return current;
}

const Object _unresolved = _Unresolved();

class _Unresolved {
  const _Unresolved();
}

String _escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

bool _falsy(Object? value) =>
    value == null ||
    identical(value, _unresolved) ||
    value == false ||
    (value is List && value.isEmpty);

void _renderNodes(List<_Node> nodes, List<Object?> stack, StringBuffer out) {
  for (final node in nodes) {
    switch (node) {
      case _Text(:final text):
        out.write(text);
      case _Interpolation(:final name, :final escape):
        final value = _lookup(stack, name);
        if (value == null || identical(value, _unresolved)) break;
        final text = value.toString();
        out.write(escape ? _escapeHtml(text) : text);
      case _Section(:final name, :final inverted, :final body):
        final value = _lookup(stack, name);
        if (inverted) {
          if (_falsy(value)) _renderNodes(body, stack, out);
        } else if (!_falsy(value)) {
          if (value is List) {
            for (final item in value) {
              stack.add(item);
              _renderNodes(body, stack, out);
              stack.removeLast();
            }
          } else {
            stack.add(value);
            _renderNodes(body, stack, out);
            stack.removeLast();
          }
        }
    }
  }
}
