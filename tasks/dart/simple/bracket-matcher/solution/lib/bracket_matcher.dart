/// Bracket matching utilities.

const Map<String, String> _closerToOpener = {')': '(', ']': '[', '}': '{'};

/// Whether every ( [ { is closed by the matching ) ] } in the right order.
bool isBalanced(String input) => firstError(input) == null;

/// Index of the first offending bracket, or null when balanced.
int? firstError(String input) {
  final openChars = <String>[];
  final openIndexes = <int>[];
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    if (ch == '(' || ch == '[' || ch == '{') {
      openChars.add(ch);
      openIndexes.add(i);
    } else {
      final opener = _closerToOpener[ch];
      if (opener == null) continue;
      if (openChars.isEmpty || openChars.last != opener) return i;
      openChars.removeLast();
      openIndexes.removeLast();
    }
  }
  if (openChars.isNotEmpty) return openIndexes.first;
  return null;
}
