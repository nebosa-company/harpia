/// Warehouse reports.

import 'inventory.dart';

/// One line per item, sorted by sku.
String stockReport(Inventory inventory) => inventory.items
    .map((i) => '${i.sku} ${i.name} onHand=${i.onHand}')
    .join('\n');

/// Items that need reordering, most urgent first.
List<Item> lowStock(Inventory inventory, int threshold) {
  final low = inventory.items.where((i) => i.onHand < threshold).toList();
  low.sort((a, b) {
    final byCount = a.onHand.compareTo(b.onHand);
    return byCount != 0 ? byCount : a.sku.compareTo(b.sku);
  });
  return low;
}
