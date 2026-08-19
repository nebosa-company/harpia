import { test } from "node:test";
import assert from "node:assert/strict";
import { assertNever, initialState, reducer, total } from "../src/reducer";
import type { CartAction, CartState } from "../src/reducer";

const state = (items: CartState["items"], coupon: string | null = null): CartState => ({
  items,
  coupon,
});

test("initialState is an empty cart", () => {
  assert.deepEqual(initialState, { items: [], coupon: null });
});

test("add appends a new sku", () => {
  const before = state([]);
  const after = reducer(before, { type: "add", sku: "a", qty: 2, unitPrice: 3 });
  assert.deepEqual(after.items, [{ sku: "a", qty: 2, unitPrice: 3 }]);
  assert.deepEqual(before.items, [], "the input state must not be mutated");
});

test("add merges into an existing sku, keeping its position and taking the new price", () => {
  const before = state([
    { sku: "a", qty: 1, unitPrice: 3 },
    { sku: "b", qty: 1, unitPrice: 4 },
  ]);
  const after = reducer(before, { type: "add", sku: "a", qty: 2, unitPrice: 5 });
  assert.deepEqual(after.items, [
    { sku: "a", qty: 3, unitPrice: 5 },
    { sku: "b", qty: 1, unitPrice: 4 },
  ]);
  assert.deepEqual(before.items[0], { sku: "a", qty: 1, unitPrice: 3 });
});

test("add with qty below 1 returns the same state object", () => {
  const before = state([{ sku: "a", qty: 1, unitPrice: 3 }]);
  assert.equal(reducer(before, { type: "add", sku: "a", qty: 0, unitPrice: 3 }), before);
  assert.equal(reducer(before, { type: "add", sku: "z", qty: -2, unitPrice: 3 }), before);
});

test("remove drops the sku, unknown sku is identity", () => {
  const before = state([
    { sku: "a", qty: 1, unitPrice: 3 },
    { sku: "b", qty: 1, unitPrice: 4 },
  ]);
  const after = reducer(before, { type: "remove", sku: "a" });
  assert.deepEqual(after.items, [{ sku: "b", qty: 1, unitPrice: 4 }]);
  assert.equal(reducer(before, { type: "remove", sku: "zz" }), before);
  assert.equal(before.items.length, 2);
});

test("setQty updates, removes at zero or less, and is identity otherwise", () => {
  const before = state([
    { sku: "a", qty: 1, unitPrice: 3 },
    { sku: "b", qty: 4, unitPrice: 4 },
  ]);
  assert.deepEqual(reducer(before, { type: "setQty", sku: "b", qty: 7 }).items, [
    { sku: "a", qty: 1, unitPrice: 3 },
    { sku: "b", qty: 7, unitPrice: 4 },
  ]);
  assert.deepEqual(reducer(before, { type: "setQty", sku: "b", qty: 0 }).items, [
    { sku: "a", qty: 1, unitPrice: 3 },
  ]);
  assert.deepEqual(reducer(before, { type: "setQty", sku: "b", qty: -3 }).items, [
    { sku: "a", qty: 1, unitPrice: 3 },
  ]);
  assert.equal(reducer(before, { type: "setQty", sku: "nope", qty: 2 }), before);
  assert.equal(reducer(before, { type: "setQty", sku: "b", qty: 4 }), before);
});

test("applyCoupon trims and upper-cases; empty and repeat are identity", () => {
  const before = state([]);
  assert.equal(reducer(before, { type: "applyCoupon", code: "  save10 " }).coupon, "SAVE10");
  assert.equal(reducer(before, { type: "applyCoupon", code: "   " }), before);
  assert.equal(reducer(before, { type: "applyCoupon", code: "" }), before);
  const applied = state([], "SAVE10");
  assert.equal(reducer(applied, { type: "applyCoupon", code: "save10" }), applied);
});

test("clearCoupon nulls the coupon and is identity when there is none", () => {
  const applied = state([], "SAVE10");
  assert.equal(reducer(applied, { type: "clearCoupon" }).coupon, null);
  const none = state([{ sku: "a", qty: 1, unitPrice: 1 }]);
  assert.equal(reducer(none, { type: "clearCoupon" }), none);
});

test("clear empties everything and is identity on an empty cart", () => {
  const full = state([{ sku: "a", qty: 1, unitPrice: 1 }], "SAVE5");
  assert.deepEqual(reducer(full, { type: "clear" }), { items: [], coupon: null });
  assert.deepEqual(full.items.length, 1);
  const empty = state([]);
  assert.equal(reducer(empty, { type: "clear" }), empty);
});

test("assertNever throws with the unhandled-variant message", () => {
  assert.throws(
    () => assertNever("boom" as never),
    (err: unknown) =>
      err instanceof Error && err.message.startsWith("unhandled variant: "),
  );
});

test("an unknown action type reaches the exhaustiveness guard", () => {
  const bogus = { type: "teleport" } as unknown as CartAction;
  assert.throws(() => reducer(state([]), bogus), Error);
});

test("total sums the lines and rounds to two decimals", () => {
  assert.equal(total(state([])), 0);
  assert.equal(
    total(
      state([
        { sku: "a", qty: 3, unitPrice: 0.1 },
        { sku: "b", qty: 1, unitPrice: 2 },
      ]),
    ),
    2.3,
  );
  assert.equal(total(state([{ sku: "a", qty: 1, unitPrice: 19.999 }])), 20);
  assert.equal(total(state([{ sku: "a", qty: 7, unitPrice: 1.234 }])), 8.64);
});

test("total applies the known coupons only", () => {
  const items = [{ sku: "a", qty: 2, unitPrice: 10 }];
  assert.equal(total(state(items, "SAVE10")), 18);
  assert.equal(total(state(items, "SAVE5")), 15);
  assert.equal(total(state(items, "BOGUS")), 20);
  assert.equal(total(state(items, null)), 20);
  assert.equal(total(state([{ sku: "a", qty: 1, unitPrice: 2 }], "SAVE5")), 0);
  assert.equal(total(state([{ sku: "a", qty: 3, unitPrice: 3.33 }], "SAVE10")), 8.99);
});
