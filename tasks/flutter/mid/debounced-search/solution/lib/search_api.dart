/// Pluggable search backend.
abstract class SearchApi {
  Future<List<String>> search(String query);
}

/// Fixed in-memory catalog with a configurable artificial delay.
class DemoSearchApi implements SearchApi {
  DemoSearchApi({this.delay = const Duration(milliseconds: 250)});

  final Duration delay;

  static const catalog = [
    'apple',
    'apricot',
    'banana',
    'blueberry',
    'cherry',
    'grape',
    'mango',
    'peach',
    'pear',
    'plum',
  ];

  @override
  Future<List<String>> search(String query) async {
    await Future<void>.delayed(delay);
    final needle = query.toLowerCase();
    return [
      for (final entry in catalog)
        if (entry.toLowerCase().contains(needle)) entry,
    ];
  }
}
