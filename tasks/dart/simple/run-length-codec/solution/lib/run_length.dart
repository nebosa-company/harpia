/// Run-length encoding for letter-only strings.

bool _isLetter(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122);

bool _isDigit(int c) => c >= 48 && c <= 57;

/// Encodes maximal runs as <count><letter>.
String rleEncode(String input) {
  for (final c in input.codeUnits) {
    if (!_isLetter(c)) {
      throw ArgumentError(
          'only ASCII letters allowed, found ${String.fromCharCode(c)}');
    }
  }
  final out = StringBuffer();
  var i = 0;
  while (i < input.length) {
    var j = i;
    while (j < input.length && input[j] == input[i]) {
      j++;
    }
    out
      ..write(j - i)
      ..write(input[i]);
    i = j;
  }
  return out.toString();
}

/// Expands <count><letter> pairs back into the original string.
String rleDecode(String encoded) {
  final out = StringBuffer();
  var i = 0;
  while (i < encoded.length) {
    var j = i;
    while (j < encoded.length && _isDigit(encoded.codeUnitAt(j))) {
      j++;
    }
    if (j == i) throw FormatException('missing count at offset $i');
    if (j >= encoded.length) throw FormatException('trailing digits');
    if (!_isLetter(encoded.codeUnitAt(j))) {
      throw FormatException('expected letter at offset $j');
    }
    final count = int.parse(encoded.substring(i, j));
    if (count == 0) throw FormatException('zero count at offset $i');
    out.write(encoded[j] * count);
    i = j + 1;
  }
  return out.toString();
}
