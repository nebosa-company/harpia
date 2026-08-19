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
  final Map<String, int> _reserved = {};

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

  int reservedOf(String sku) {
    itemBySku(sku);
    return _reserved[sku] ?? 0;
  }

  int availableOf(String sku) => itemBySku(sku).onHand - reservedOf(sku);

  void reserve(String sku, int quantity) {
    if (quantity < 1) throw ArgumentError('quantity must be positive');
    if (quantity > availableOf(sku)) {
      throw StateError('insufficient available stock for $sku');
    }
    _reserved[sku] = reservedOf(sku) + quantity;
  }

  void release(String sku, int quantity) {
    if (quantity < 1) throw ArgumentError('quantity must be positive');
    final held = reservedOf(sku);
    if (quantity > held) {
      throw ArgumentError('release exceeds reservation for $sku');
    }
    _reserved[sku] = held - quantity;
  }

  bool ship(String sku, int quantity) {
    if (quantity < 1) throw ArgumentError('quantity must be positive');
    final item = itemBySku(sku);
    if (quantity <= availableOf(sku)) {
      item.onHand -= quantity;
      return true;
    }
    return false;
  }

  bool shipReserved(String sku, int quantity) {
    if (quantity < 1) throw ArgumentError('quantity must be positive');
    final item = itemBySku(sku);
    final held = reservedOf(sku);
    if (quantity > held) return false;
    item.onHand -= quantity;
    _reserved[sku] = held - quantity;
    return true;
  }

  List<Item> get items {
    final all = _items.values.toList();
    all.sort((a, b) => a.sku.compareTo(b.sku));
    return all;
  }
}
