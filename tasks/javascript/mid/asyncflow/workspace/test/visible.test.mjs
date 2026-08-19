// Visible suite. Written so it works whether the module uses callbacks or
// promises, so it must keep passing across the refactor. Do not edit.
import test from "node:test";
import assert from "node:assert/strict";
import { createCatalog } from "../catalog.mjs";
import { resolveRecipe, priceBasket } from "../flow.mjs";

const DATA = {
  cake: { cost: 5, parts: ["flour", "egg"] },
  flour: { cost: 2, parts: ["wheat"] },
  wheat: { cost: 1, parts: [] },
  egg: { cost: 3, parts: [] },
};

function invoke(fn, ...args) {
  return new Promise((resolve, reject) => {
    const returned = fn(...args, (err, value) => {
      if (err) reject(err);
      else resolve(value);
    });
    if (returned && typeof returned.then === "function") {
      returned.then(resolve, reject);
    }
  });
}

test("resolveRecipe builds the tree with rolled-up costs", async () => {
  const catalog = createCatalog(DATA);
  const tree = await invoke(resolveRecipe, catalog, "cake");
  assert.equal(tree.name, "cake");
  assert.equal(tree.cost, 11);
  assert.deepEqual(
    tree.parts.map((p) => p.name),
    ["flour", "egg"],
  );
  assert.equal(tree.parts[0].cost, 3);
  assert.equal(tree.parts[0].parts[0].name, "wheat");
});

test("resolveRecipe handles a leaf", async () => {
  const catalog = createCatalog(DATA);
  const tree = await invoke(resolveRecipe, catalog, "egg");
  assert.deepEqual(tree, { name: "egg", cost: 3, parts: [] });
});

test("resolveRecipe reports an unknown name", async () => {
  const catalog = createCatalog(DATA);
  await assert.rejects(() => invoke(resolveRecipe, catalog, "sugar"), (err) => {
    assert.equal(err.code, "NOT_FOUND");
    return true;
  });
});

test("priceBasket totals the lines in order", async () => {
  const catalog = createCatalog(DATA);
  const result = await invoke(priceBasket, catalog, [
    { name: "egg", qty: 2 },
    { name: "flour", qty: 3 },
  ]);
  assert.equal(result.total, 12);
  assert.deepEqual(result.lines, [
    { name: "egg", qty: 2, unit: 3, subtotal: 6 },
    { name: "flour", qty: 3, unit: 2, subtotal: 6 },
  ]);
});

test("priceBasket of an empty basket costs nothing", async () => {
  const catalog = createCatalog(DATA);
  const result = await invoke(priceBasket, catalog, []);
  assert.deepEqual(result, { total: 0, lines: [] });
});

test("priceBasket reports an unknown name", async () => {
  const catalog = createCatalog(DATA);
  await assert.rejects(() => invoke(priceBasket, catalog, [{ name: "sugar", qty: 1 }]), (err) => {
    assert.equal(err.code, "NOT_FOUND");
    return true;
  });
});
