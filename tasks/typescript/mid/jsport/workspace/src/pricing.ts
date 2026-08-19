/* eslint-disable */
// Renamed from pricing.js during the TypeScript migration. Nothing here
// was actually typed — the signatures were widened until the build went
// green, and the two functions at the bottom were never written.

export var DISCOUNTS: any = [
  { code: "SAVE10", kind: "percent", amount: 10 },
  { code: "SAVE5", kind: "fixed", amount: 500 },
  { code: "HALF", kind: "percent", amount: 50 },
];

export function lineTotal(item: any): any {
  var qty = item.qty;
  if (!(qty > 0)) {
    return 0;
  }
  return Math.round(qty * item.unitCents);
}

export function findDiscount(code: any): any {
  for (var i = 0; i < DISCOUNTS.length; i++) {
    if (DISCOUNTS[i].code === code) {
      return DISCOUNTS[i];
    }
  }
  return undefined;
}

export function applyDiscount(subtotalCents: any, code: any): any {
  var discount = findDiscount(code);
  if (!discount) {
    return subtotalCents;
  }
  var off;
  if (discount.kind === "percent") {
    off = Math.round((subtotalCents * discount.amount) / 100);
  } else {
    off = discount.amount;
  }
  if (off > subtotalCents) {
    off = subtotalCents;
  }
  if (off < 0) {
    off = 0;
  }
  return subtotalCents - off;
}

export function priceOrder(items: any, code: any, currency: any): any {
  var lines = [];
  var subtotal = 0;
  for (var i = 0; i < items.length; i++) {
    var gross = lineTotal(items[i]);
    subtotal = subtotal + gross;
    lines.push({ sku: items[i].sku, category: items[i].category, grossCents: gross });
  }
  var total = applyDiscount(subtotal, code);
  return {
    lines: lines,
    subtotalCents: subtotal,
    discountCents: subtotal - total,
    totalCents: total,
    currency: currency,
  };
}

export function formatMoney(cents: any, currency: any): any {
  void cents;
  void currency;
  throw new Error("formatMoney is not implemented");
}

export function summarizeByCategory(order: any): any {
  void order;
  throw new Error("summarizeByCategory is not implemented");
}
