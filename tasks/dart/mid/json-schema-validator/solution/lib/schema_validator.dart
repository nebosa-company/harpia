/// Miniature JSON-schema validation.

/// All validation errors for [data] against [schema]; empty when valid.
List<String> validate(Object? data, Map<String, Object?> schema) {
  final errors = <String>[];
  _validateNode(data, schema, '/', errors);
  return errors;
}

/// Whether [data] satisfies [schema].
bool isValid(Object? data, Map<String, Object?> schema) =>
    validate(data, schema).isEmpty;

String _child(String parent, String key) =>
    parent == '/' ? '/$key' : '$parent/$key';

bool _matchesType(Object? data, String type) {
  switch (type) {
    case 'string':
      return data is String;
    case 'integer':
      return data is int;
    case 'number':
      return data is num;
    case 'boolean':
      return data is bool;
    case 'array':
      return data is List;
    case 'object':
      return data is Map;
    case 'null':
      return data == null;
    default:
      return false;
  }
}

bool _deepEq(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEq(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEq(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

void _validateNode(Object? data, Map<String, Object?> schema, String path,
    List<String> errors) {
  final type = schema['type'];
  if (type is String && !_matchesType(data, type)) {
    errors.add('$path: expected $type');
    return;
  }
  final allowed = schema['enum'];
  if (allowed is List && !allowed.any((e) => _deepEq(e, data))) {
    errors.add('$path: value not in enum');
    return;
  }
  if (data is num) {
    final minimum = schema['minimum'];
    if (minimum is num && data < minimum) {
      errors.add('$path: must be >= $minimum');
    }
    final maximum = schema['maximum'];
    if (maximum is num && data > maximum) {
      errors.add('$path: must be <= $maximum');
    }
  }
  if (data is String) {
    final minLength = schema['minLength'];
    if (minLength is int && data.length < minLength) {
      errors.add('$path: length must be >= $minLength');
    }
    final maxLength = schema['maxLength'];
    if (maxLength is int && data.length > maxLength) {
      errors.add('$path: length must be <= $maxLength');
    }
  }
  if (data is Map) {
    final required = schema['required'];
    if (required is List) {
      for (final name in required) {
        if (!data.containsKey(name)) {
          errors.add("$path: missing required property '$name'");
        }
      }
    }
    final properties = schema['properties'];
    if (properties is Map) {
      for (final entry in properties.entries) {
        final name = entry.key as String;
        if (data.containsKey(name)) {
          _validateNode(
              data[name],
              (entry.value as Map).cast<String, Object?>(),
              _child(path, name),
              errors);
        }
      }
    }
    if (schema['additionalProperties'] == false) {
      final known = properties is Map ? properties.keys.toSet() : <Object?>{};
      for (final key in data.keys) {
        if (!known.contains(key)) {
          errors.add('${_child(path, '$key')}: unexpected property');
        }
      }
    }
  }
  if (data is List) {
    final items = schema['items'];
    if (items is Map) {
      for (var i = 0; i < data.length; i++) {
        _validateNode(
            data[i], items.cast<String, Object?>(), _child(path, '$i'), errors);
      }
    }
  }
}
