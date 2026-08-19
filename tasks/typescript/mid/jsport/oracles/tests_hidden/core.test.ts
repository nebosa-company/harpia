import { test } from "node:test";
import assert from "node:assert/strict";
import {
  DISCOUNTS,
  applyDiscount,
  findDiscount,
  formatMoney,
  lineTotal,
  priceOrder,
  summarizeByCategory,
} from "../src/pricing";

test("the discount table is unchanged", () => {
  assert.deepEqual([...DISCOUNTS], [
    { code: "SAVE10", kind: "percent", amount: 10 },
    { code: "SAVE5", kind: "fixed", amount: 500 },
    { code: "HALF", kind: "percent", amount: 50 },
  ]);
});

test("lineTotal is preserved", () => {
  assert.equal(lineTotal({ sku: "a", qty: 3, unitCents: 250, category: "x" }), 750);
  assert.equal(lineTotal({ sku: "a", qty: 0, unitCents: 250, category: "x" }), 0);
  assert.equal(lineTotal({ sku: "a", qty: -1, unitCents: 250, category: "x" }), 0);
  assert.equal(lineTotal({ sku: "a", qty: 2.5, unitCents: 101, category: "x" }), 253);
});

test("findDiscount is preserved", () => {
  assert.deepEqual(findDiscount("HALF"), { code: "HALF", kind: "percent", amount: 50 });
  assert.equal(findDiscount("half"), undefined);
  assert.equal(findDiscount(""), undefined);
});

test("applyDiscount is preserved", () => {
  assert.equal(applyDiscount(1000, "SAVE10"), 900);
  assert.equal(applyDiscount(1000, "SAVE5"), 500);
  assert.equal(applyDiscount(1000, "HALF"), 500);
  assert.equal(applyDiscount(1000, "NOPE"), 1000);
  assert.equal(applyDiscount(1000, null), 1000);
  assert.equal(applyDiscount(200, "SAVE5"), 0);
  assert.equal(applyDiscount(1005, "SAVE10"), 904);
  assert.equal(applyDiscount(0, "HALF"), 0);
});

test("priceOrder is preserved", () => {
  const order = priceOrder(
    [
      { sku: "a", qty: 2, unitCents: 500, category: "books" },
      { sku: "b", qty: 1, unitCents: 250, category: "music" },
    ],
    "SAVE10",
    "EUR",
  );
  assert.deepEqual(order, {
    lines: [
      { sku: "a", category: "books", grossCents: 1000 },
      { sku: "b", category: "music", grossCents: 250 },
    ],
    subtotalCents: 1250,
    discountCents: 125,
    totalCents: 1125,
    currency: "EUR",
  });
  assert.deepEqual(priceOrder([], null, "USD"), {
    lines: [],
    subtotalCents: 0,
    discountCents: 0,
    totalCents: 0,
    currency: "USD",
  });
});

test("formatMoney renders each currency", () => {
  assert.equal(formatMoney(1234, "EUR"), "€12.34");
  assert.equal(formatMoney(1234, "GBP"), "£12.34");
  assert.equal(formatMoney(1234, "USD"), "$12.34");
});

test("formatMoney pads the cents and handles zero", () => {
  assert.equal(formatMoney(0, "USD"), "$0.00");
  assert.equal(formatMoney(5, "GBP"), "£0.05");
  assert.equal(formatMoney(50, "GBP"), "£0.50");
  assert.equal(formatMoney(100, "USD"), "$1.00");
  assert.equal(formatMoney(100000, "EUR"), "€1000.00");
});

test("formatMoney puts a negative sign before the symbol", () => {
  assert.equal(formatMoney(-1234, "EUR"), "-€12.34");
  assert.equal(formatMoney(-5, "USD"), "-$0.05");
});

test("formatMoney refuses fractional and non-finite amounts", () => {
  const whole = (err: unknown): boolean =>
    err instanceof RangeError && err.message === "cents must be a whole number";
  assert.throws(() => formatMoney(1.5, "EUR"), whole);
  assert.throws(() => formatMoney(Number.NaN, "EUR"), whole);
  assert.throws(() => formatMoney(Number.POSITIVE_INFINITY, "EUR"), whole);
});

test("summarizeByCategory groups, sorts and shares", () => {
  const order = priceOrder(
    [
      { sku: "a", qty: 2, unitCents: 500, category: "books" },
      { sku: "b", qty: 1, unitCents: 250, category: "music" },
      { sku: "c", qty: 3, unitCents: 100, category: "books" },
    ],
    null,
    "EUR",
  );
  assert.equal(order.subtotalCents, 1550);
  assert.deepEqual(summarizeByCategory(order), [
    { category: "books", grossCents: 1300, share: 0.8387 },
    { category: "music", grossCents: 250, share: 0.1613 },
  ]);
});

test("summarizeByCategory breaks ties by category name", () => {
  const order = priceOrder(
    [
      { sku: "a", qty: 1, unitCents: 500, category: "zeta" },
      { sku: "b", qty: 1, unitCents: 500, category: "alpha" },
      { sku: "c", qty: 1, unitCents: 500, category: "mid" },
    ],
    null,
    "EUR",
  );
  assert.deepEqual(
    summarizeByCategory(order).map((entry) => entry.category),
    ["alpha", "mid", "zeta"],
  );
});

test("summarizeByCategory handles empty and zero-value orders", () => {
  assert.deepEqual(summarizeByCategory(priceOrder([], null, "EUR")), []);
  const free = priceOrder(
    [
      { sku: "a", qty: 0, unitCents: 500, category: "books" },
      { sku: "b", qty: 0, unitCents: 500, category: "music" },
    ],
    null,
    "EUR",
  );
  assert.deepEqual(summarizeByCategory(free), [
    { category: "books", grossCents: 0, share: 0 },
    { category: "music", grossCents: 0, share: 0 },
  ]);
});
