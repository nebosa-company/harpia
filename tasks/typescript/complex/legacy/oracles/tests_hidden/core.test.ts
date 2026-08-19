import { test } from "node:test";
import assert from "node:assert/strict";
import { DISCOUNTS, PRODUCTS, discountFor, findProduct } from "../src/catalog";
import { applyDiscount, priceLine } from "../src/pricing";
import {
  adjustmentValue,
  assertNever,
  buildReceipt,
  priceOrder,
} from "../src/orders";

test("the catalogue data is unchanged", () => {
  assert.deepEqual([...PRODUCTS], [
    { sku: "BK-1", name: "Notebook", priceCents: 450, category: "stationery" },
    { sku: "PN-2", name: "Pen", priceCents: 150, category: "stationery" },
    { sku: "MG-3", name: "Mug", priceCents: 900, category: "kitchen" },
    { sku: "TE-4", name: "Tea", priceCents: 600, category: "kitchen" },
  ]);
  assert.deepEqual([...DISCOUNTS], [
    { sku: "MG-3", percent: 20 },
    { sku: "TE-4", percent: 10 },
  ]);
});

test("lookups answer with the catalogue's own conventions", () => {
  assert.deepEqual(findProduct("PN-2"), {
    sku: "PN-2",
    name: "Pen",
    priceCents: 150,
    category: "stationery",
  });
  assert.equal(findProduct("ZZ-9"), undefined);
  assert.deepEqual(discountFor("MG-3"), { sku: "MG-3", percent: 20 });
  assert.equal(discountFor("BK-1"), null, "no discount is null, not undefined");
});

test("an undiscounted line prices at its gross", () => {
  assert.equal(applyDiscount("BK-1", 900), 900);
  assert.equal(applyDiscount("PN-2", 150), 150);
  assert.equal(applyDiscount("ZZ-9", 100), 100);
});

test("a discounted line takes its percentage off", () => {
  assert.equal(applyDiscount("MG-3", 900), 720);
  assert.equal(applyDiscount("TE-4", 600), 540);
  assert.equal(applyDiscount("TE-4", 605), 544, "the discount rounds half up");
});

test("priceLine builds a full line", () => {
  assert.deepEqual(priceLine({ sku: "BK-1", qty: 2 }), {
    sku: "BK-1",
    name: "Notebook",
    category: "stationery",
    qty: 2,
    grossCents: 900,
    netCents: 900,
  });
  assert.deepEqual(priceLine({ sku: "MG-3", qty: 1 }), {
    sku: "MG-3",
    name: "Mug",
    category: "kitchen",
    qty: 1,
    grossCents: 900,
    netCents: 720,
  });
});

test("priceLine answers null for a sku the catalogue does not have", () => {
  assert.equal(priceLine({ sku: "ZZ-9", qty: 3 }), null);
});

test("adjustmentValue covers all three kinds", () => {
  assert.equal(adjustmentValue({ kind: "credit", cents: 500 }, 1000), -500);
  assert.equal(adjustmentValue({ kind: "fee", cents: 250, reason: "wrap" }, 1000), 250);
  assert.equal(adjustmentValue({ kind: "tax", rate: 10 }, 1620), 162);
  assert.equal(adjustmentValue({ kind: "tax", rate: 21 }, 1005), 211);
  assert.equal(adjustmentValue({ kind: "tax", rate: 0 }, 1000), 0);
});

test("assertNever refuses anything it is handed", () => {
  assert.throws(
    () => assertNever("surprise" as never),
    (err: unknown) =>
      err instanceof Error && err.message.startsWith("unhandled adjustment: "),
  );
});

test("an unknown adjustment kind reaches the exhaustiveness guard", () => {
  assert.throws(
    () => adjustmentValue({ kind: "rebate" } as never, 100),
    Error,
  );
});

test("an order with an unknown sku prices the rest and records the reject", () => {
  const priced = priceOrder({
    id: "A-1",
    items: [
      { sku: "BK-1", qty: 2 },
      { sku: "ZZ-9", qty: 3 },
      { sku: "MG-3", qty: 1 },
    ],
    adjustments: [],
  });
  assert.deepEqual(priced.rejected, ["ZZ-9"]);
  assert.deepEqual(
    priced.lines.map((line) => line.sku),
    ["BK-1", "MG-3"],
  );
  assert.equal(priced.subtotalCents, 1620);
  assert.equal(priced.totalCents, 1620);
});

test("rejects keep their input order and their repeats", () => {
  const priced = priceOrder({
    id: "A-2",
    items: [
      { sku: "QQ-1", qty: 1 },
      { sku: "BK-1", qty: 1 },
      { sku: "ZZ-9", qty: 1 },
      { sku: "QQ-1", qty: 5 },
    ],
    adjustments: [],
  });
  assert.deepEqual(priced.rejected, ["QQ-1", "ZZ-9", "QQ-1"]);
});

test("a tax adjustment is measured against the subtotal", () => {
  const priced = priceOrder({
    id: "A-3",
    items: [
      { sku: "BK-1", qty: 2 },
      { sku: "MG-3", qty: 1 },
    ],
    adjustments: [{ kind: "tax", rate: 10 }],
  });
  assert.equal(priced.subtotalCents, 1620);
  assert.equal(priced.adjustmentCents, 162);
  assert.equal(priced.totalCents, 1782);
  assert.equal(Number.isNaN(priced.totalCents), false);
});

test("adjustments accumulate in order and all use the same subtotal", () => {
  const priced = priceOrder({
    id: "A-4",
    items: [{ sku: "MG-3", qty: 2 }],
    adjustments: [
      { kind: "credit", cents: 500 },
      { kind: "fee", cents: 250, reason: "gift wrap" },
      { kind: "tax", rate: 10 },
    ],
  });
  assert.equal(priced.subtotalCents, 1440);
  assert.equal(priced.adjustmentCents, -500 + 250 + 144);
  assert.equal(priced.totalCents, 1440 - 106);
});

test("the total is floored at zero", () => {
  const priced = priceOrder({
    id: "A-5",
    items: [{ sku: "PN-2", qty: 6 }],
    adjustments: [{ kind: "credit", cents: 2000 }],
  });
  assert.equal(priced.subtotalCents, 900);
  assert.equal(priced.adjustmentCents, -2000);
  assert.equal(priced.totalCents, 0);
});

test("an empty order prices to zero and carries its adjustments through", () => {
  const priced = priceOrder({ id: "A-6", items: [], adjustments: [] });
  assert.deepEqual(priced, {
    id: "A-6",
    lines: [],
    rejected: [],
    adjustments: [],
    subtotalCents: 0,
    adjustmentCents: 0,
    totalCents: 0,
  });
});

test("the priced order keeps the adjustments in order", () => {
  const priced = priceOrder({
    id: "A-7",
    items: [],
    adjustments: [
      { kind: "fee", cents: 100, reason: "handling" },
      { kind: "credit", cents: 50 },
    ],
  });
  assert.deepEqual(priced.adjustments, [
    { kind: "fee", cents: 100, reason: "handling" },
    { kind: "credit", cents: 50 },
  ]);
});

test("the receipt renders a whole order", () => {
  const priced = priceOrder({
    id: "A-8",
    items: [
      { sku: "BK-1", qty: 2 },
      { sku: "MG-3", qty: 1 },
      { sku: "ZZ-9", qty: 3 },
    ],
    adjustments: [{ kind: "tax", rate: 10 }],
  });
  assert.deepEqual(buildReceipt(priced), [
    "ORDER A-8",
    "Notebook x2 9.00",
    "Mug x1 7.20",
    "SUBTOTAL 16.20",
    "TAX 10% 1.62",
    "TOTAL 17.82",
    "REJECTED ZZ-9",
  ]);
});

test("the receipt labels each adjustment kind", () => {
  const priced = priceOrder({
    id: "A-9",
    items: [{ sku: "MG-3", qty: 2 }],
    adjustments: [
      { kind: "credit", cents: 500 },
      { kind: "fee", cents: 250, reason: "gift wrap" },
    ],
  });
  assert.deepEqual(buildReceipt(priced), [
    "ORDER A-9",
    "Mug x2 14.40",
    "SUBTOTAL 14.40",
    "CREDIT -5.00",
    "FEE (gift wrap) 2.50",
    "TOTAL 11.90",
  ]);
});

test("the receipt omits the rejected line when nothing was rejected", () => {
  const priced = priceOrder({
    id: "A-10",
    items: [{ sku: "PN-2", qty: 1 }],
    adjustments: [],
  });
  assert.deepEqual(buildReceipt(priced), [
    "ORDER A-10",
    "Pen x1 1.50",
    "SUBTOTAL 1.50",
    "TOTAL 1.50",
  ]);
});

test("the receipt lists every rejected sku", () => {
  const priced = priceOrder({
    id: "A-11",
    items: [
      { sku: "QQ-1", qty: 1 },
      { sku: "ZZ-9", qty: 1 },
    ],
    adjustments: [],
  });
  assert.deepEqual(buildReceipt(priced), [
    "ORDER A-11",
    "SUBTOTAL 0.00",
    "TOTAL 0.00",
    "REJECTED QQ-1, ZZ-9",
  ]);
});

test("money pads and signs correctly through the receipt", () => {
  const priced = priceOrder({
    id: "A-12",
    items: [],
    adjustments: [
      { kind: "fee", cents: 5, reason: "rounding" },
      { kind: "credit", cents: 5 },
    ],
  });
  assert.deepEqual(buildReceipt(priced), [
    "ORDER A-12",
    "SUBTOTAL 0.00",
    "FEE (rounding) 0.05",
    "CREDIT -0.05",
    "TOTAL 0.00",
  ]);
});
