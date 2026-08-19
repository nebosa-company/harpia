import 'dart:math' as math;

/// A paged source of item labels. Pages are 0-based; a page past the end
/// resolves to an empty list.
abstract class ItemRepository {
  Future<List<String>> fetchPage(int page);
}

/// In-memory demo source: 95 items in pages of 20.
class DemoItemRepository implements ItemRepository {
  DemoItemRepository({this.delay = const Duration(milliseconds: 200)});

  final Duration delay;

  static const int totalItems = 95;
  static const int pageSize = 20;

  @override
  Future<List<String>> fetchPage(int page) async {
    await Future<void>.delayed(delay);
    final start = page * pageSize;
    if (start >= totalItems) {
      return const [];
    }
    final end = math.min(start + pageSize, totalItems);
    return [for (var i = start; i < end; i++) 'Item ${i + 1}'];
  }
}
