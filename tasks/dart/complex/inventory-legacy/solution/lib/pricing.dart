/// Volume pricing.

import 'inventory.dart';

class PriceQuote {
  final int subtotalCents;
  final int discountCents;
  final int totalCents;

  PriceQuote(this.subtotalCents, this.discountCents, this.totalCents);
}

/// Volume discount tiers: 5% from 10 units, 10% from 50, 15% from 100.
int discountPercent(int quantity) {
  if (quantity >= 100) return 15;
  if (quantity >= 50) return 10;
  if (quantity >= 10) return 5;
  return 0;
}

/// Quotes [quantity] units of [item]; the discount is floored to cents.
PriceQuote quote(Item item, int quantity) {
  if (quantity < 1) throw ArgumentError('quantity must be positive');
  final subtotal = item.unitPriceCents * quantity;
  final discount = subtotal * discountPercent(quantity) ~/ 100;
  return PriceQuote(subtotal, discount, subtotal - discount);
}
