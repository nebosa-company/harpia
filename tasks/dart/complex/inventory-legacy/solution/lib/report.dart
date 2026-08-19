/// Warehouse reports.

import 'inventory.dart';

/// One line per item, sorted by sku.
String stockReport(Inventory inventory) => inventory.items
    .map((i) => '${i.sku} ${i.name} onHand=${i.onHand} '
        'reserved=${inventory.reservedOf(i.sku)} '
        'available=${inventory.availableOf(i.sku)}')
    .join('\n');

/// Items whose available stock is at or below [threshold], most urgent
/// first (available ascending, ties by sku).
List<Item> lowStock(Inventory inventory, int threshold) {
  final low = inventory.items
      .where((i) => inventory.availableOf(i.sku) <= threshold)
      .toList();
  low.sort((a, b) {
    final byAvailable =
        inventory.availableOf(a.sku).compareTo(inventory.availableOf(b.sku));
    return byAvailable != 0 ? byAvailable : a.sku.compareTo(b.sku);
  });
  return low;
}
