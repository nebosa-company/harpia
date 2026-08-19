/// Arithmetic expression evaluation.

import 'dart:math' as math;

/// Evaluates [expression] with the given [variables]; see the brief for the
/// grammar, precedence table, and error contract.
num evaluate(String expression, {Map<String, num> variables = const {}}) {
  final parser = _Parser(_tokenize(expression), variables);
  final value = parser.parseExpression(0);
  parser.expectEnd();
  return value;
}

class _Token {
  final String kind; // num, ident, op, end
  final String text;
  final num? value;

  _Token(this.kind, this.text, [this.value]);
}

bool _isDigit(int c) => c >= 48 && c <= 57;

bool _isIdentStart(int c) =>
    (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;

bool _isIdentPart(int c) => _isIdentStart(c) || _isDigit(c);

List<_Token> _tokenize(String input) {
  final tokens = <_Token>[];
  var i = 0;
  while (i < input.length) {
    final c = input.codeUnitAt(i);
    if (c == 32 || c == 9 || c == 10 || c == 13) {
      i++;
      continue;
    }
    if (_isDigit(c)) {
      var j = i;
      while (j < input.length && _isDigit(input.codeUnitAt(j))) {
        j++;
      }
      var isDouble = false;
      if (j < input.length && input[j] == '.') {
        if (j + 1 >= input.length || !_isDigit(input.codeUnitAt(j + 1))) {
          throw FormatException('malformed number at offset $i');
        }
        isDouble = true;
        j++;
        while (j < input.length && _isDigit(input.codeUnitAt(j))) {
          j++;
        }
      }
      final text = input.substring(i, j);
      tokens.add(_Token(
          'num', text, isDouble ? double.parse(text) : int.parse(text)));
      i = j;
      continue;
    }
    if (_isIdentStart(c)) {
      var j = i;
      while (j < input.length && _isIdentPart(input.codeUnitAt(j))) {
        j++;
      }
      tokens.add(_Token('ident', input.substring(i, j)));
      i = j;
      continue;
    }
    const ops = '+-*/%^(),';
    final ch = input[i];
    if (ops.contains(ch)) {
      tokens.add(_Token('op', ch));
      i++;
      continue;
    }
    throw FormatException('unexpected character $ch at offset $i');
  }
  tokens.add(_Token('end', ''));
  return tokens;
}

class _Parser {
  final List<_Token> _tokens;
  final Map<String, num> _variables;
  int _pos = 0;

  _Parser(this._tokens, this._variables);

  _Token get _peek => _tokens[_pos];

  _Token _next() => _tokens[_pos++];

  bool _isOp(String text) => _peek.kind == 'op' && _peek.text == text;

  void _expectOp(String text) {
    if (!_isOp(text)) {
      throw FormatException('expected $text, found ${_describe(_peek)}');
    }
    _pos++;
  }

  String _describe(_Token t) => t.kind == 'end' ? 'end of input' : t.text;

  void expectEnd() {
    if (_peek.kind != 'end') {
      throw FormatException('trailing input: ${_describe(_peek)}');
    }
  }

  // Precedence: 10 for + -, 20 for * / %, 30 for ^ (right-assoc).
  // Unary minus sits between 20 and 30: its operand is parseExpression(25),
  // so ^ binds tighter than unary minus and -2^2 == -(2^2).
  num parseExpression(int minPrec) {
    var left = _parseUnary();
    while (true) {
      final t = _peek;
      if (t.kind != 'op') break;
      final prec = switch (t.text) {
        '+' || '-' => 10,
        '*' || '/' || '%' => 20,
        '^' => 30,
        _ => -1,
      };
      if (prec < minPrec) break;
      _pos++;
      final right =
          t.text == '^' ? parseExpression(30) : parseExpression(prec + 1);
      left = switch (t.text) {
        '+' => left + right,
        '-' => left - right,
        '*' => left * right,
        '/' => left / right,
        '%' => left % right,
        _ => math.pow(left, right),
      };
    }
    return left;
  }

  num _parseUnary() {
    if (_isOp('-')) {
      _pos++;
      return -parseExpression(25);
    }
    return _parsePrimary();
  }

  num _parsePrimary() {
    final t = _next();
    if (t.kind == 'num') return t.value!;
    if (t.kind == 'ident') {
      if (_isOp('(')) {
        _pos++;
        final args = <num>[];
        if (_isOp(')')) {
          throw FormatException('empty argument list for ${t.text}');
        }
        args.add(parseExpression(0));
        while (_isOp(',')) {
          _pos++;
          args.add(parseExpression(0));
        }
        _expectOp(')');
        return _call(t.text, args);
      }
      final value = _variables[t.text];
      if (value == null) throw ArgumentError('unknown variable: ${t.text}');
      return value;
    }
    if (t.kind == 'op' && t.text == '(') {
      final value = parseExpression(0);
      _expectOp(')');
      return value;
    }
    throw FormatException('unexpected ${_describe(t)}');
  }

  num _call(String name, List<num> args) {
    num arity(int n) {
      if (args.length != n) {
        throw ArgumentError('$name takes $n argument${n == 1 ? '' : 's'}');
      }
      return 0;
    }

    switch (name) {
      case 'min':
        arity(2);
        return math.min(args[0], args[1]);
      case 'max':
        arity(2);
        return math.max(args[0], args[1]);
      case 'abs':
        arity(1);
        return args[0].abs();
      case 'sqrt':
        arity(1);
        return math.sqrt(args[0]);
      default:
        throw ArgumentError('unknown function: $name');
    }
  }
}
