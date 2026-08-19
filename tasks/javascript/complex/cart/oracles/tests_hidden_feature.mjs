import test from "node:test";
import assert from "node:assert/strict";
import { createBus } from "./bus.mjs";
import { catalog } from "./catalog.mjs";
import { createCart } from "./cart.mjs";

function setup() {
  const bus = createBus();
  const cart = createCart({ bus, catalog });
  const changes = [];
  const coupons = [];
  bus.on("change", (event) => changes.push(event));
  bus.on("coupon", (event) => coupons.push(event));
  return { bus, cart, changes, coupons };
}

test("a percent coupon discounts the subtotal", () => {
  const { cart } = setup();
  cart.addItem("SKU-WIDGET", 2);
  assert.equal(cart.subtotal, 2598);
  assert.equal(cart.applyCoupon("SAVE10"), 2338);
  assert.equal(cart.discount, 260);
  assert.equal(cart.total, 2338);
  assert.equal(cart.subtotal, 2598, "the subtotal itself is untouched");
  assert.equal(cart.coupon, "SAVE10");
});

test("a percent discount rounds to the nearest cent", () => {
  const { cart } = setup();
  cart.addItem("SKU-WIDGET");
  assert.equal(cart.subtotal, 1299);
  cart.applyCoupon("SAVE10");
  assert.equal(cart.discount, 130);
  assert.equal(cart.total, 1169);
});

test("an amount coupon takes its value", () => {
  const { cart } = setup();
  cart.addItem("SKU-WIDGET");
  cart.applyCoupon("FIVEOFF");
  assert.equal(cart.discount, 500);
  assert.equal(cart.total, 799);
});

test("an amount coupon never exceeds the subtotal", () => {
  const { cart } = setup();
  cart.addItem("SKU-TRINKET");
  assert.equal(cart.subtotal, 89);
  cart.applyCoupon("BIGDEAL");
  assert.equal(cart.discount, 89);
  assert.equal(cart.total, 0);
});

test("an unknown code is rejected and nothing changes", () => {
  const { cart, changes, coupons } = setup();
  cart.addItem("SKU-WIDGET");
  changes.length = 0;
  assert.throws(
    () => cart.applyCoupon("NOPE"),
    (err) => {
      assert.equal(err.code, "UNKNOWN_COUPON");
      return true;
    },
  );
  assert.equal(cart.coupon, null);
  assert.equal(cart.discount, 0);
  assert.deepEqual(changes, []);
  assert.deepEqual(coupons, []);
});

test("a coupon below its minimum subtotal is rejected", () => {
  const { cart, changes } = setup();
  cart.addItem("SKU-WIDGET");
  assert.equal(cart.subtotal, 1299);
  changes.length = 0;
  assert.throws(
    () => cart.applyCoupon("SAVE25"),
    (err) => {
      assert.equal(err.code, "COUPON_NOT_ELIGIBLE");
      return true;
    },
  );
  assert.equal(cart.coupon, null);
  assert.equal(cart.total, 1299);
  assert.deepEqual(changes, []);
});

test("a coupon becomes usable once the subtotal is high enough", () => {
  const { cart } = setup();
  cart.addItem("SKU-ANVIL");
  assert.equal(cart.subtotal, 7500);
  assert.equal(cart.applyCoupon("SAVE25"), 5625);
  assert.equal(cart.discount, 1875);
});

test("applying a second coupon replaces the first", () => {
  const { cart, coupons } = setup();
  cart.addItem("SKU-ANVIL");
  cart.applyCoupon("SAVE10");
  assert.equal(cart.discount, 750);
  cart.applyCoupon("SAVE25");
  assert.equal(cart.coupon, "SAVE25");
  assert.equal(cart.discount, 1875);
  assert.equal(cart.total, 5625);
  assert.deepEqual(coupons, [
    { code: "SAVE10", discount: 750 },
    { code: "SAVE25", discount: 1875 },
  ]);
});

test("a replacement that is not eligible leaves the first coupon in place", () => {
  const { cart } = setup();
  cart.addItem("SKU-WIDGET");
  cart.applyCoupon("SAVE10");
  assert.throws(() => cart.applyCoupon("SAVE25"), (err) => err.code === "COUPON_NOT_ELIGIBLE");
  assert.equal(cart.coupon, "SAVE10");
  assert.equal(cart.discount, 130);
});

test("removeCoupon reports whether there was one", () => {
  const { cart, changes, coupons } = setup();
  cart.addItem("SKU-WIDGET");
  assert.equal(cart.removeCoupon(), false);
  cart.applyCoupon("SAVE10");
  changes.length = 0;
  coupons.length = 0;
  assert.equal(cart.removeCoupon(), true);
  assert.equal(cart.coupon, null);
  assert.equal(cart.discount, 0);
  assert.equal(cart.total, 1299);
  assert.deepEqual(coupons, [{ code: null, discount: 0 }]);
  assert.deepEqual(changes, [{ reason: "coupon", sku: null }]);
  assert.equal(cart.removeCoupon(), false);
});

test("applying a coupon emits the coupon event then one change", () => {
  const { bus, cart } = setup();
  cart.addItem("SKU-WIDGET", 2);
  const order = [];
  bus.on("coupon", (event) => order.push(["coupon", event.code, event.discount]));
  bus.on("change", (event) => order.push(["change", event.reason, event.sku]));
  cart.applyCoupon("SAVE10");
  assert.deepEqual(order, [
    ["coupon", "SAVE10", 260],
    ["change", "coupon", null],
  ]);
});

test("the discount follows quantity changes", () => {
  const { cart } = setup();
  cart.addItem("SKU-GADGET", 2);
  cart.applyCoupon("SAVE10");
  assert.equal(cart.discount, 90);
  assert.equal(cart.total, 810);
  cart.setQuantity("SKU-GADGET", 10);
  assert.equal(cart.subtotal, 4500);
  assert.equal(cart.discount, 450);
  assert.equal(cart.total, 4050);
  cart.addItem("SKU-TRINKET");
  assert.equal(cart.subtotal, 4589);
  assert.equal(cart.discount, 459);
  assert.equal(cart.total, 4130);
});

test("the discount follows a price update", () => {
  const { bus, cart } = setup();
  cart.addItem("SKU-GADGET", 2);
  cart.applyCoupon("SAVE10");
  bus.emit("price:updated", { sku: "SKU-GADGET", price: 1000 });
  assert.equal(cart.subtotal, 2000);
  assert.equal(cart.discount, 200);
  assert.equal(cart.total, 1800);
});

test("an amount coupon shrinks with an emptying cart", () => {
  const { cart } = setup();
  cart.addItem("SKU-WIDGET");
  cart.applyCoupon("FIVEOFF");
  assert.equal(cart.total, 799);
  cart.setQuantity("SKU-WIDGET", 0);
  assert.equal(cart.subtotal, 0);
  assert.equal(cart.discount, 0);
  assert.equal(cart.total, 0);
});

test("eligibility is only checked when the coupon is applied", () => {
  const { cart } = setup();
  cart.addItem("SKU-ANVIL");
  cart.applyCoupon("SAVE25");
  cart.setQuantity("SKU-ANVIL", 1);
  cart.removeItem("SKU-ANVIL");
  cart.addItem("SKU-TRINKET");
  assert.equal(cart.coupon, "SAVE25");
  assert.equal(cart.subtotal, 89);
  assert.equal(cart.discount, 22);
  assert.equal(cart.total, 67);
});

test("clear keeps the coupon and empties the cart", () => {
  const { cart, changes } = setup();
  cart.addItem("SKU-WIDGET");
  cart.applyCoupon("SAVE10");
  changes.length = 0;
  cart.clear();
  assert.deepEqual(changes, [{ reason: "clear", sku: null }]);
  assert.equal(cart.coupon, "SAVE10");
  assert.equal(cart.subtotal, 0);
  assert.equal(cart.discount, 0);
  assert.equal(cart.total, 0);
});

test("a coupon applied to an empty cart discounts nothing", () => {
  const { cart } = setup();
  assert.equal(cart.applyCoupon("SAVE10"), 0);
  assert.equal(cart.discount, 0);
  cart.addItem("SKU-GADGET");
  assert.equal(cart.discount, 45);
  assert.equal(cart.total, 405);
});
