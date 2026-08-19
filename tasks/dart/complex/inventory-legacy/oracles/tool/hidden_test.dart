import 'dart:io';

import '../lib/inventory.dart';
import '../lib/pricing.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected $expected, got $actual');
    failures++;
  }
}

void expectThrows<T>(String label, void Function() fn) {
  try {
    fn();
    print('FAIL $label: expected $T, nothing thrown');
    failures++;
  } on Object catch (e) {
    if (e is! T) {
      print('FAIL $label: expected $T, got ${e.runtimeType}');
      failures++;
    }
  }
}

Inventory stocked() {
  final inv = Inventory();
  inv.addItem(Item('A1', 'Anchor', unitPriceCents: 999));
  inv.addItem(Item('B2', 'Bolt', unitPriceCents: 5));
  inv.receive('A1', 10);
  inv.receive('B2', 500);
  return inv;
}

void main() {
  // Symptom 1: shipping exactly the stock on hand must succeed.
  final inv = stocked();
  check('ship all', inv.ship('A1', 10), true);
  check('emptied', inv.itemBySku('A1').onHand, 0);
  check('ship from empty', inv.ship('A1', 1), false);
  check('partial ship', inv.ship('B2', 499), true);
  check('last unit', inv.ship('B2', 1), true);
  check('b2 empty', inv.itemBySku('B2').onHand, 0);

  // Symptom 2: discount tiers are inclusive at 10/50/100.
  check('tier 9', discountPercent(9), 0);
  check('tier 10', discountPercent(10), 5);
  check('tier 49', discountPercent(49), 5);
  check('tier 50', discountPercent(50), 10);
  check('tier 99', discountPercent(99), 10);
  check('tier 100', discountPercent(100), 15);
  check('tier 250', discountPercent(250), 15);

  final q = quote(Item('X', 'X', unitPriceCents: 999), 10);
  check('quote subtotal', q.subtotalCents, 9990);
  check('quote discount floored', q.discountCents, 499);
  check('quote total', q.totalCents, 9491);
  expectThrows<ArgumentError>(
      'quote zero', () => quote(Item('X', 'X', unitPriceCents: 1), 0));

  // Reservations: the requested feature.
  final r = stocked();
  r.reserve('A1', 4);
  check('reserved', r.reservedOf('A1'), 4);
  check('available', r.availableOf('A1'), 6);
  check('onHand untouched by hold', r.itemBySku('A1').onHand, 10);

  check('ship beyond available', r.ship('A1', 7), false);
  check('ship available exactly', r.ship('A1', 6), true);
  check('after ship onHand', r.itemBySku('A1').onHand, 4);
  check('after ship available', r.availableOf('A1'), 0);

  check('shipReserved', r.shipReserved('A1', 3), true);
  check('after shipReserved onHand', r.itemBySku('A1').onHand, 1);
  check('after shipReserved reserved', r.reservedOf('A1'), 1);

  r.release('A1', 1);
  check('released', r.reservedOf('A1'), 0);
  check('release restores available', r.availableOf('A1'), 1);

  check('shipReserved over held', r.shipReserved('A1', 1), false);
  check('failed shipReserved no change', r.itemBySku('A1').onHand, 1);

  check('zero reservation default', r.reservedOf('B2'), 0);
  check('available equals onHand', r.availableOf('B2'), 500);

  expectThrows<StateError>('over-reserve', () => r.reserve('A1', 2));
  expectThrows<ArgumentError>('release too much', () => r.release('B2', 1));
  expectThrows<ArgumentError>('reserve zero', () => r.reserve('B2', 0));
  expectThrows<ArgumentError>('release zero', () => r.release('B2', 0));
  expectThrows<ArgumentError>('shipReserved zero', () => r.shipReserved('B2', 0));
  expectThrows<StateError>('reserve unknown', () => r.reserve('ZZ', 1));
  expectThrows<StateError>('reservedOf unknown', () => r.reservedOf('ZZ'));
  expectThrows<StateError>('availableOf unknown', () => r.availableOf('ZZ'));
  if (failures > 0) exit(1);
  print('core ok');
}
