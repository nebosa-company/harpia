import test from "node:test";
import assert from "node:assert/strict";
import { createCatalog } from "./catalog.mjs";
import { resolveRecipe, priceBasket } from "./flow.mjs";

const DATA = {
  cake: { cost: 5, parts: ["flour", "egg"] },
  flour: { cost: 2, parts: ["wheat"] },
  wheat: { cost: 1, parts: [] },
  egg: { cost: 3, parts: [] },
  bread: { cost: 4, parts: ["flour", "flour"] },
};

test("resolveRecipe returns a promise for the tree, with no callback", async () => {
  const catalog = createCatalog(DATA);
  const returned = resolveRecipe(catalog, "cake");
  assert.equal(typeof returned.then, "function");
  const tree = await returned;
  assert.equal(tree.name, "cake");
  assert.equal(tree.cost, 11);
  assert.deepEqual(
    tree.parts.map((p) => [p.name, p.cost]),
    [
      ["flour", 3],
      ["egg", 3],
    ],
  );
  assert.deepEqual(tree.parts[0].parts, [{ name: "wheat", cost: 1, parts: [] }]);
});

test("resolveRecipe keeps parts in the listed order", async () => {
  const catalog = createCatalog(DATA);
  const tree = await resolveRecipe(catalog, "bread");
  assert.deepEqual(
    tree.parts.map((p) => p.name),
    ["flour", "flour"],
  );
  assert.equal(tree.cost, 10);
});

test("resolveRecipe on a leaf", async () => {
  const catalog = createCatalog(DATA);
  assert.deepEqual(await resolveRecipe(catalog, "wheat"), { name: "wheat", cost: 1, parts: [] });
});

test("resolveRecipe rejects with the catalog error and its code", async () => {
  const catalog = createCatalog(DATA);
  await assert.rejects(resolveRecipe(catalog, "sugar"), (err) => {
    assert.equal(err.code, "NOT_FOUND");
    assert.match(err.message, /sugar/);
    return true;
  });
});

test("a failure deep in the tree surfaces", async () => {
  const catalog = createCatalog({ ...DATA, cake: { cost: 5, parts: ["flour", "sugar"] } });
  await assert.rejects(resolveRecipe(catalog, "cake"), (err) => err.code === "NOT_FOUND");
});

test("priceBasket returns a promise for totals and lines", async () => {
  const catalog = createCatalog(DATA);
  const returned = priceBasket(catalog, [
    { name: "egg", qty: 2 },
    { name: "flour", qty: 3 },
    { name: "cake", qty: 1 },
  ]);
  assert.equal(typeof returned.then, "function");
  const result = await returned;
  assert.deepEqual(result.lines, [
    { name: "egg", qty: 2, unit: 3, subtotal: 6 },
    { name: "flour", qty: 3, unit: 2, subtotal: 6 },
    { name: "cake", qty: 1, unit: 5, subtotal: 5 },
  ]);
  assert.equal(result.total, 17);
});

test("priceBasket of an empty basket looks nothing up", async () => {
  const catalog = createCatalog(DATA);
  assert.deepEqual(await priceBasket(catalog, []), { total: 0, lines: [] });
  assert.equal(catalog.stats().lookups, 0);
});

test("priceBasket rejects on an unknown item", async () => {
  const catalog = createCatalog(DATA);
  await assert.rejects(priceBasket(catalog, [{ name: "egg", qty: 1 }, { name: "sugar", qty: 1 }]), (err) => {
    assert.equal(err.code, "NOT_FOUND");
    return true;
  });
});

test("priceBasket handles a single line", async () => {
  const catalog = createCatalog(DATA);
  const result = await priceBasket(catalog, [{ name: "wheat", qty: 10 }]);
  assert.equal(result.total, 10);
  assert.deepEqual(result.lines, [{ name: "wheat", qty: 10, unit: 1, subtotal: 10 }]);
});

test("the same catalog serves several calls", async () => {
  const catalog = createCatalog(DATA);
  const [tree, priced] = await Promise.all([
    resolveRecipe(catalog, "flour"),
    priceBasket(catalog, [{ name: "egg", qty: 1 }]),
  ]);
  assert.equal(tree.cost, 3);
  assert.equal(priced.total, 3);
});
