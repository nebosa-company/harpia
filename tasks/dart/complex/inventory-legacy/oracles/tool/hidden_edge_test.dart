import 'dart:io';

import '../lib/inventory.dart';
import '../lib/pricing.dart';
import '../lib/report.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected <$expected>, got <$actual>');
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

void main() {
  // Report format with reservations, sorted by sku.
  final inv = Inventory();
  inv.addItem(Item('C3', 'Clamp', unitPriceCents: 250));
  inv.addItem(Item('A1', 'Anchor', unitPriceCents: 999));
  inv.addItem(Item('B2', 'Bolt', unitPriceCents: 5));
  inv.receive('A1', 8);
  inv.receive('B2', 3);
  inv.receive('C3', 5);
  inv.reserve('A1', 2);
  inv.reserve('C3', 5);
  check(
      'stock report',
      stockReport(inv),
      'A1 Anchor onHand=8 reserved=2 available=6\n'
      'B2 Bolt onHand=3 reserved=0 available=3\n'
      'C3 Clamp onHand=5 reserved=5 available=0');

  // Symptom 3: threshold is inclusive, ordering by available then sku.
  final low = lowStock(inv, 3);
  check('low count', low.length, 2);
  check('low first', low[0].sku, 'C3'); // available 0
  check('low second', low[1].sku, 'B2'); // available 3, exactly at threshold
  check('not low', lowStock(inv, 3).any((i) => i.sku == 'A1'), false);

  final zeroLow = lowStock(inv, 0);
  check('zero threshold', zeroLow.length, 1);
  check('zero threshold sku', zeroLow[0].sku, 'C3');

  // Ties order by sku.
  final tied = Inventory();
  tied.addItem(Item('D4', 'Dowel', unitPriceCents: 1, onHand: 2));
  tied.addItem(Item('A9', 'Axle', unitPriceCents: 1, onHand: 2));
  final tiedLow = lowStock(tied, 5);
  check('tie order first', tiedLow[0].sku, 'A9');
  check('tie order second', tiedLow[1].sku, 'D4');

  // End-to-end: receive, reserve, ship, price, report all interact.
  final flow = Inventory();
  flow.addItem(Item('P1', 'Pallet', unitPriceCents: 100));
  flow.receive('P1', 100);
  flow.reserve('P1', 40);
  check('flow ship over available', flow.ship('P1', 61), false);
  check('flow ship at available', flow.ship('P1', 60), true);
  check('flow shipReserved', flow.shipReserved('P1', 40), true);
  check('flow empty', flow.itemBySku('P1').onHand, 0);
  check('flow report', stockReport(flow),
      'P1 Pallet onHand=0 reserved=0 available=0');
  final flowQuote = quote(flow.itemBySku('P1'), 50);
  check('flow quote', flowQuote.totalCents, 4500);
  check('flow low stock', lowStock(flow, 0).length, 1);

  // Ledger hygiene.
  expectThrows<ArgumentError>(
      'duplicate sku',
      () => tied.addItem(Item('A9', 'Duplicate', unitPriceCents: 1)));
  expectThrows<ArgumentError>('receive zero', () => tied.receive('A9', 0));
  expectThrows<StateError>('unknown item', () => tied.itemBySku('QQ'));
  expectThrows<ArgumentError>('ship zero', () => tied.ship('A9', 0));
  final sorted = inv.items.map((i) => i.sku).join(',');
  check('items sorted', sorted, 'A1,B2,C3');

  // Reservations survive partial releases.
  final hold = Inventory();
  hold.addItem(Item('H1', 'Hook', unitPriceCents: 9, onHand: 10));
  hold.reserve('H1', 6);
  hold.release('H1', 2);
  hold.reserve('H1', 1);
  check('net reservation', hold.reservedOf('H1'), 5);
  check('net available', hold.availableOf('H1'), 5);
  if (failures > 0) exit(1);
  print('edge ok');
}
