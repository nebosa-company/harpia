/// Path routing with parameters and wildcards.

/// A successful route lookup.
class RouteMatch<T> {
  final T handler;
  final Map<String, String> params;

  RouteMatch(this.handler, this.params);
}

class _Seg {
  final int kind; // 0 literal, 1 param, 2 wildcard
  final String text; // literal text, or capture name

  _Seg(this.kind, this.text);
}

class _Route<T> {
  final List<_Seg> segs;
  final T handler;

  _Route(this.segs, this.handler);
}

/// Registers path patterns and resolves paths against them.
class Router<T> {
  final List<_Route<T>> _routes = [];
  final Set<String> _signatures = {};

  void add(String pattern, T handler) {
    final segs = _parsePattern(pattern);
    final sig = segs
        .map((s) => s.kind == 0 ? 'L${s.text}' : (s.kind == 1 ? ':' : '*'))
        .join('/');
    if (!_signatures.add(sig)) {
      throw ArgumentError('equivalent pattern already registered: $pattern');
    }
    _routes.add(_Route(segs, handler));
  }

  RouteMatch<T>? match(String path) {
    if (!path.startsWith('/')) return null;
    var p = path;
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    final parts = p == '/' ? <String>[] : p.substring(1).split('/');
    if (parts.any((s) => s.isEmpty)) return null;
    _Route<T>? best;
    for (final route in _routes) {
      if (!_matches(route.segs, parts)) continue;
      if (best == null || _morePrecise(route.segs, best.segs)) best = route;
    }
    if (best == null) return null;
    return RouteMatch(best.handler, _capture(best.segs, parts));
  }

  List<_Seg> _parsePattern(String pattern) {
    if (!pattern.startsWith('/')) {
      throw ArgumentError('pattern must start with /');
    }
    var p = pattern;
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    if (p == '/') return [];
    final parts = p.substring(1).split('/');
    final segs = <_Seg>[];
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) throw ArgumentError('empty segment in pattern');
      if (part.startsWith(':')) {
        if (part.length == 1) throw ArgumentError('missing parameter name');
        segs.add(_Seg(1, part.substring(1)));
      } else if (part.startsWith('*')) {
        if (part.length == 1) throw ArgumentError('missing wildcard name');
        if (i != parts.length - 1) {
          throw ArgumentError('wildcard must be the final segment');
        }
        segs.add(_Seg(2, part.substring(1)));
      } else {
        segs.add(_Seg(0, part));
      }
    }
    return segs;
  }

  bool _matches(List<_Seg> segs, List<String> parts) {
    final hasWildcard = segs.isNotEmpty && segs.last.kind == 2;
    if (hasWildcard) {
      if (parts.length < segs.length - 1) return false;
    } else if (parts.length != segs.length) {
      return false;
    }
    for (var i = 0; i < segs.length; i++) {
      final seg = segs[i];
      if (seg.kind == 2) return true;
      if (seg.kind == 0 && parts[i] != seg.text) return false;
    }
    return true;
  }

  /// Lexicographic comparison of segment kinds: literal < param < wildcard;
  /// a route that ends where the other still has a wildcard is more precise.
  bool _morePrecise(List<_Seg> a, List<_Seg> b) {
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final ka = i < a.length ? a[i].kind : -1;
      final kb = i < b.length ? b[i].kind : -1;
      if (ka != kb) return ka < kb;
    }
    return false;
  }

  String _decode(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  Map<String, String> _capture(List<_Seg> segs, List<String> parts) {
    final params = <String, String>{};
    for (var i = 0; i < segs.length; i++) {
      final seg = segs[i];
      if (seg.kind == 1) {
        params[seg.text] = _decode(parts[i]);
      } else if (seg.kind == 2) {
        params[seg.text] = parts.sublist(i).map(_decode).join('/');
      }
    }
    return params;
  }
}
