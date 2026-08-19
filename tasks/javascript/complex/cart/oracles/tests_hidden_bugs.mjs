import test from "node:test";
import assert from "node:assert/strict";
import { createBus } from "./bus.mjs";
import { catalog } from "./catalog.mjs";
import { createCart } from "./cart.mjs";

function setup() {
  const bus = createBus();
  const cart = createCart({ bus, catalog });
  const changes = [];
  bus.on("change", (event) => changes.push(event));
  return { bus, cart, changes };
}

test("adding and removing leaves no price subscriber behind", () => {
  const { bus, cart } = setup();
  const baseline = bus.listenerCount("price:updated");
  for (let i = 0; i < 5; i++) {
    cart.addItem("SKU-WIDGET");
    cart.addItem("SKU-GADGET", 2);
    cart.removeItem("SKU-WIDGET");
    cart.removeItem("SKU-GADGET");
  }
  assert.equal(bus.listenerCount("price:updated"), baseline);
});

test("adding the same sku twice does not add a second subscriber", () => {
  const { bus, cart } = setup();
  cart.addItem("SKU-WIDGET");
  const afterFirst = bus.listenerCount("price:updated");
  cart.addItem("SKU-WIDGET");
  cart.addItem("SKU-WIDGET", 3);
  assert.equal(bus.listenerCount("price:updated"), afterFirst);
});

test("clear releases every subscription", () => {
  const { bus, cart } = setup();
  const baseline = bus.listenerCount("price:updated");
  cart.addItem("SKU-WIDGET");
  cart.addItem("SKU-GADGET");
  cart.addItem("SKU-TRINKET");
  cart.clear();
  assert.equal(bus.listenerCount("price:updated"), baseline);
});

test("a price update fires exactly one change per affected line", () => {
  const { bus, cart, changes } = setup();
  cart.addItem("SKU-WIDGET");
  cart.addItem("SKU-WIDGET", 2);
  changes.length = 0;
  bus.emit("price:updated", { sku: "SKU-WIDGET", price: 1000 });
  assert.deepEqual(changes, [{ reason: "price", sku: "SKU-WIDGET" }]);
});

test("a price update for a removed item changes nothing", () => {
  const { bus, cart, changes } = setup();
  cart.addItem("SKU-WIDGET");
  cart.addItem("SKU-GADGET");
  cart.removeItem("SKU-WIDGET");
  changes.length = 0;
  bus.emit("price:updated", { sku: "SKU-WIDGET", price: 1 });
  assert.deepEqual(changes, []);
  assert.equal(cart.subtotal, 450);
});

test("subtotal and total follow a quantity change", () => {
  const { cart } = setup();
  cart.addItem("SKU-WIDGET");
  assert.equal(cart.subtotal, 1299);
  cart.setQuantity("SKU-WIDGET", 3);
  assert.equal(cart.subtotal, 3897);
  assert.equal(cart.total, 3897);
  assert.equal(cart.itemCount, 3);
  cart.setQuantity("SKU-WIDGET", 1);
  assert.equal(cart.subtotal, 1299);
  assert.equal(cart.total, 1299);
});

test("subtotal follows a price update", () => {
  const { bus, cart } = setup();
  cart.addItem("SKU-GADGET", 2);
  assert.equal(cart.subtotal, 900);
  bus.emit("price:updated", { sku: "SKU-GADGET", price: 500 });
  assert.equal(cart.subtotal, 1000);
  assert.equal(cart.total, 1000);
  assert.equal(cart.lines()[0].unitPrice, 500);
  assert.equal(cart.lines()[0].lineTotal, 1000);
});

test("the numbers are right at the moment the change event fires", () => {
  const { bus, cart } = setup();
  cart.addItem("SKU-WIDGET", 2);
  const seen = [];
  bus.on("change", (event) => seen.push({ reason: event.reason, subtotal: cart.subtotal }));
  cart.setQuantity("SKU-WIDGET", 4);
  bus.emit("price:updated", { sku: "SKU-WIDGET", price: 1000 });
  assert.deepEqual(seen, [
    { reason: "quantity", subtotal: 5196 },
    { reason: "price", subtotal: 4000 },
  ]);
});

test("adding an item already in the cart fires one change", () => {
  const { cart, changes } = setup();
  cart.addItem("SKU-WIDGET");
  changes.length = 0;
  cart.addItem("SKU-WIDGET");
  assert.deepEqual(changes, [{ reason: "add", sku: "SKU-WIDGET" }]);
  assert.equal(cart.itemCount, 2);
  changes.length = 0;
  cart.addItem("SKU-WIDGET", 5);
  assert.equal(changes.length, 1);
  assert.equal(cart.itemCount, 7);
});

test("every mutation fires exactly one change with the right reason", () => {
  const { cart, changes } = setup();
  cart.addItem("SKU-WIDGET");
  cart.setQuantity("SKU-WIDGET", 2);
  cart.addItem("SKU-GADGET");
  cart.removeItem("SKU-GADGET");
  cart.setQuantity("SKU-WIDGET", 0);
  cart.addItem("SKU-TRINKET");
  cart.clear();
  assert.deepEqual(changes, [
    { reason: "add", sku: "SKU-WIDGET" },
    { reason: "quantity", sku: "SKU-WIDGET" },
    { reason: "add", sku: "SKU-GADGET" },
    { reason: "remove", sku: "SKU-GADGET" },
    { reason: "remove", sku: "SKU-WIDGET" },
    { reason: "add", sku: "SKU-TRINKET" },
    { reason: "clear", sku: null },
  ]);
});

test("a failed operation changes nothing and fires nothing", () => {
  const { cart, changes } = setup();
  cart.addItem("SKU-WIDGET");
  changes.length = 0;
  assert.throws(() => cart.addItem("SKU-NOPE"), (err) => err.code === "UNKNOWN_SKU");
  assert.throws(() => cart.addItem("SKU-WIDGET", 0), TypeError);
  assert.throws(() => cart.addItem("SKU-WIDGET", 1.5), TypeError);
  assert.throws(() => cart.setQuantity("SKU-GADGET", 2), (err) => err.code === "NO_SUCH_LINE");
  assert.throws(() => cart.setQuantity("SKU-WIDGET", -1), TypeError);
  assert.deepEqual(changes, []);
  assert.equal(cart.itemCount, 1);
  assert.equal(cart.subtotal, 1299);
});

test("removeItem reports whether it removed anything", () => {
  const { cart, changes } = setup();
  cart.addItem("SKU-WIDGET");
  changes.length = 0;
  assert.equal(cart.removeItem("SKU-GADGET"), false);
  assert.deepEqual(changes, []);
  assert.equal(cart.removeItem("SKU-WIDGET"), true);
  assert.equal(changes.length, 1);
});

test("lines keep their insertion order and are copies", () => {
  const { cart } = setup();
  cart.addItem("SKU-TRINKET", 2);
  cart.addItem("SKU-WIDGET");
  cart.addItem("SKU-TRINKET");
  const lines = cart.lines();
  assert.deepEqual(
    lines.map((line) => [line.sku, line.qty]),
    [
      ["SKU-TRINKET", 3],
      ["SKU-WIDGET", 1],
    ],
  );
  assert.deepEqual(lines[0], {
    sku: "SKU-TRINKET",
    name: "Trinket",
    qty: 3,
    unitPrice: 89,
    lineTotal: 267,
  });
  lines[0].qty = 99;
  assert.equal(cart.lines()[0].qty, 3);
  assert.equal(cart.itemCount, 4);
});

test("setQuantity returns a snapshot and zero removes the line", () => {
  const { cart } = setup();
  cart.addItem("SKU-GADGET");
  assert.deepEqual(cart.setQuantity("SKU-GADGET", 3), {
    sku: "SKU-GADGET",
    name: "Gadget",
    qty: 3,
    unitPrice: 450,
    lineTotal: 1350,
  });
  assert.equal(cart.setQuantity("SKU-GADGET", 0), null);
  assert.deepEqual(cart.lines(), []);
  assert.equal(cart.subtotal, 0);
});

test("addItem returns the line it produced", () => {
  const { cart } = setup();
  assert.deepEqual(cart.addItem("SKU-WIDGET", 2), {
    sku: "SKU-WIDGET",
    name: "Widget",
    qty: 2,
    unitPrice: 1299,
    lineTotal: 2598,
  });
  assert.equal(cart.addItem("SKU-WIDGET").qty, 3);
});

test("an empty cart totals zero", () => {
  const { cart } = setup();
  assert.equal(cart.subtotal, 0);
  assert.equal(cart.total, 0);
  assert.equal(cart.discount, 0);
  assert.equal(cart.itemCount, 0);
  assert.deepEqual(cart.lines(), []);
});

test("two carts on one bus stay independent", () => {
  const bus = createBus();
  const first = createCart({ bus, catalog });
  const second = createCart({ bus, catalog });
  first.addItem("SKU-WIDGET");
  assert.equal(second.itemCount, 0);
  assert.equal(second.subtotal, 0);
  bus.emit("price:updated", { sku: "SKU-WIDGET", price: 100 });
  assert.equal(first.subtotal, 100);
  assert.equal(second.subtotal, 0);
});
