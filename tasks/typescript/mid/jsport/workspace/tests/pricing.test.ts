import { test } from "node:test";
import assert from "node:assert/strict";
import {
  DISCOUNTS,
  applyDiscount,
  findDiscount,
  lineTotal,
  priceOrder,
} from "../src/pricing";

test("the discount table holds the three known codes", () => {
  assert.deepEqual(
    DISCOUNTS.map((d: { code: string }) => d.code),
    ["SAVE10", "SAVE5", "HALF"],
  );
});

test("lineTotal multiplies quantity by unit price", () => {
  assert.equal(lineTotal({ sku: "a", qty: 3, unitCents: 250, category: "x" }), 750);
  assert.equal(lineTotal({ sku: "a", qty: 1, unitCents: 99, category: "x" }), 99);
});

test("a quantity of zero or less is worth nothing", () => {
  assert.equal(lineTotal({ sku: "a", qty: 0, unitCents: 250, category: "x" }), 0);
  assert.equal(lineTotal({ sku: "a", qty: -2, unitCents: 250, category: "x" }), 0);
});

test("findDiscount looks a code up", () => {
  assert.deepEqual(findDiscount("SAVE5"), {
    code: "SAVE5",
    kind: "fixed",
    amount: 500,
  });
  assert.equal(findDiscount("NOPE"), undefined);
});

test("applyDiscount handles both kinds", () => {
  assert.equal(applyDiscount(1000, "SAVE10"), 900);
  assert.equal(applyDiscount(1000, "SAVE5"), 500);
  assert.equal(applyDiscount(1000, "HALF"), 500);
  assert.equal(applyDiscount(1000, "NOPE"), 1000);
  assert.equal(applyDiscount(1000, null), 1000);
});

test("a discount never takes more than the subtotal", () => {
  assert.equal(applyDiscount(200, "SAVE5"), 0);
  assert.equal(applyDiscount(0, "SAVE10"), 0);
});

test("percent discounts round to the nearest cent", () => {
  assert.equal(applyDiscount(1005, "SAVE10"), 904);
});

test("priceOrder builds the priced lines and the totals", () => {
  const order = priceOrder(
    [
      { sku: "a", qty: 2, unitCents: 500, category: "books" },
      { sku: "b", qty: 1, unitCents: 250, category: "music" },
    ],
    "SAVE10",
    "EUR",
  );
  assert.deepEqual(order.lines, [
    { sku: "a", category: "books", grossCents: 1000 },
    { sku: "b", category: "music", grossCents: 250 },
  ]);
  assert.equal(order.subtotalCents, 1250);
  assert.equal(order.discountCents, 125);
  assert.equal(order.totalCents, 1125);
  assert.equal(order.currency, "EUR");
});

test("an empty order prices to zero", () => {
  const order = priceOrder([], null, "GBP");
  assert.deepEqual(order.lines, []);
  assert.equal(order.subtotalCents, 0);
  assert.equal(order.discountCents, 0);
  assert.equal(order.totalCents, 0);
  assert.equal(order.currency, "GBP");
});
