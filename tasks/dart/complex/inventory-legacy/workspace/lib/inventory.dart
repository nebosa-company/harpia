/// Core stock ledger.

class Item {
  final String sku;
  final String name;
  final int unitPriceCents;
  int onHand;

  Item(this.sku, this.name, {required this.unitPriceCents, this.onHand = 0});
}

class Inventory {
  final Map<String, Item> _items = {};

  void addItem(Item item) {
    if (_items.containsKey(item.sku)) {
      throw ArgumentError('duplicate sku: ${item.sku}');
    }
    _items[item.sku] = item;
  }

  Item itemBySku(String sku) {
    final item = _items[sku];
    if (item == null) throw StateError('unknown sku: $sku');
    return item;
  }

  void receive(String sku, int quantity) {
    if (quantity < 1) throw ArgumentError('quantity must be positive');
    itemBySku(sku).onHand += quantity;
  }

  bool ship(String sku, int quantity) {
    if (quantity < 1) throw ArgumentError('quantity must be positive');
    final item = itemBySku(sku);
    if (item.onHand > quantity) {
      item.onHand -= quantity;
      return true;
    }
    return false;
  }

  List<Item> get items {
    final all = _items.values.toList();
    all.sort((a, b) => a.sku.compareTo(b.sku));
    return all;
  }
}
