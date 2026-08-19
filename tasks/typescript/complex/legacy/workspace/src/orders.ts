/* The order pipeline. Renamed from orders.js; never typed.
 * The receipt was specced but never written. */
import { priceLine } from "./pricing";

export function assertNever(value: any): never {
  throw new Error("unhandled adjustment: " + JSON.stringify(value));
}

export function adjustmentValue(adjustment: any, subtotalCents: any): any {
  switch (adjustment.kind) {
    case "credit":
      return -adjustment.cents;
    case "fee":
      return adjustment.cents;
  }
}

export function priceOrder(order: any): any {
  var lines = [];
  var subtotal = 0;
  for (var i = 0; i < order.items.length; i++) {
    var line = priceLine(order.items[i]);
    subtotal = subtotal + line.netCents;
    lines.push(line);
  }
  var adjustments = 0;
  for (var j = 0; j < order.adjustments.length; j++) {
    adjustments = adjustments + adjustmentValue(order.adjustments[j], subtotal);
  }
  var total = subtotal + adjustments;
  if (total < 0) {
    total = 0;
  }
  return {
    id: order.id,
    lines: lines,
    rejected: [],
    adjustments: order.adjustments,
    subtotalCents: subtotal,
    adjustmentCents: adjustments,
    totalCents: total,
  };
}

export function buildReceipt(priced: any): any {
  void priced;
  throw new Error("buildReceipt is not implemented");
}
