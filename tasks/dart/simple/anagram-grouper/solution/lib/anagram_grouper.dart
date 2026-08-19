/// Grouping words by anagram class.

/// Groups [words] into anagram classes; see the brief for ordering rules.
List<List<String>> groupAnagrams(List<String> words) {
  final groups = <String, List<String>>{};
  for (final word in words) {
    final units = word.toLowerCase().codeUnits.toList()..sort();
    final key = String.fromCharCodes(units);
    groups.putIfAbsent(key, () => []).add(word);
  }
  return groups.values.toList();
}
