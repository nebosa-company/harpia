import test from "node:test";
import assert from "node:assert/strict";
import { createCatalog } from "./catalog.mjs";
import { resolveRecipe, priceBasket, expand } from "./flow.mjs";

const DATA = {
  cake: { cost: 5, parts: ["flour", "egg"] },
  flour: { cost: 2, parts: ["wheat"] },
  wheat: { cost: 1, parts: [] },
  egg: { cost: 3, parts: [] },
  bread: { cost: 4, parts: ["flour", "flour"] },
};

test("priceBasket looks each distinct name up once, all at the same time", async () => {
  const catalog = createCatalog(DATA);
  const result = await priceBasket(catalog, [
    { name: "egg", qty: 1 },
    { name: "flour", qty: 1 },
    { name: "wheat", qty: 1 },
    { name: "egg", qty: 2 },
  ]);
  assert.equal(result.total, 3 + 2 + 1 + 6);
  const { lookups, peak } = catalog.stats();
  assert.equal(lookups, 3, "each distinct name is looked up exactly once");
  assert.equal(peak, 3, "the lookups must overlap, not run one after the other");
});

test("a repeated name still produces one line each", async () => {
  const catalog = createCatalog(DATA);
  const result = await priceBasket(catalog, [
    { name: "egg", qty: 1 },
    { name: "egg", qty: 4 },
  ]);
  assert.deepEqual(result.lines, [
    { name: "egg", qty: 1, unit: 3, subtotal: 3 },
    { name: "egg", qty: 4, unit: 3, subtotal: 12 },
  ]);
  assert.equal(catalog.stats().lookups, 1);
});

test("expand is an async generator", () => {
  const catalog = createCatalog(DATA);
  const it = expand(catalog, "cake");
  assert.equal(typeof it[Symbol.asyncIterator], "function");
  assert.equal(it[Symbol.asyncIterator](), it);
  assert.equal(typeof it.next, "function");
  assert.equal(typeof it.return, "function");
});

test("expand yields names in pre-order", async () => {
  const catalog = createCatalog(DATA);
  const names = [];
  for await (const name of expand(catalog, "cake")) names.push(name);
  assert.deepEqual(names, ["cake", "flour", "wheat", "egg"]);
});

test("a repeated ingredient is yielded every time it appears", async () => {
  const catalog = createCatalog(DATA);
  const names = [];
  for await (const name of expand(catalog, "bread")) names.push(name);
  assert.deepEqual(names, ["bread", "flour", "wheat", "flour", "wheat"]);
});

test("expand of a leaf yields one name", async () => {
  const catalog = createCatalog(DATA);
  const names = [];
  for await (const name of expand(catalog, "egg")) names.push(name);
  assert.deepEqual(names, ["egg"]);
});

test("expand is lazy: one pull, one lookup", async () => {
  const catalog = createCatalog(DATA);
  const it = expand(catalog, "cake");
  assert.equal(catalog.stats().lookups, 0, "creating the iterator looks nothing up");
  assert.deepEqual(await it.next(), { value: "cake", done: false });
  assert.equal(catalog.stats().lookups, 1);
  assert.deepEqual(await it.next(), { value: "flour", done: false });
  assert.equal(catalog.stats().lookups, 2);
});

test("stopping early leaves the rest of the tree alone", async () => {
  const catalog = createCatalog(DATA);
  const names = [];
  for await (const name of expand(catalog, "cake")) {
    names.push(name);
    if (names.length === 2) break;
  }
  assert.deepEqual(names, ["cake", "flour"]);
  assert.equal(catalog.stats().lookups, 2);
});

test("expand throws out of the loop on an unknown name", async () => {
  const catalog = createCatalog(DATA);
  await assert.rejects(
    async () => {
      for await (const name of expand(catalog, "sugar")) {
        assert.fail(`unexpected ${name}`);
      }
    },
    (err) => {
      assert.equal(err.code, "NOT_FOUND");
      return true;
    },
  );
});

test("expand throws when a nested name is missing, after yielding what it had", async () => {
  const catalog = createCatalog({ ...DATA, cake: { cost: 5, parts: ["sugar"] } });
  const names = [];
  await assert.rejects(
    async () => {
      for await (const name of expand(catalog, "cake")) names.push(name);
    },
    (err) => err.code === "NOT_FOUND",
  );
  assert.deepEqual(names, ["cake"]);
});

test("no exported function calls a callback handed to it", async () => {
  const catalog = createCatalog(DATA);
  let called = false;
  const mark = () => {
    called = true;
  };
  const tree = await resolveRecipe(catalog, "wheat", mark);
  assert.deepEqual(tree, { name: "wheat", cost: 1, parts: [] });
  const priced = await priceBasket(catalog, [{ name: "egg", qty: 1 }], mark);
  assert.equal(priced.total, 3);
  const names = [];
  for await (const name of expand(catalog, "egg", mark)) names.push(name);
  assert.deepEqual(names, ["egg"]);
  assert.equal(called, false, "the module must not invoke caller callbacks any more");
});

test("resolveRecipe is not blocked by an unrelated failure", async () => {
  const catalog = createCatalog(DATA);
  const results = await Promise.allSettled([
    resolveRecipe(catalog, "sugar"),
    resolveRecipe(catalog, "flour"),
  ]);
  assert.equal(results[0].status, "rejected");
  assert.equal(results[1].status, "fulfilled");
  assert.equal(results[1].value.cost, 3);
});

test("a deep chain rolls its costs up", async () => {
  const deep = {
    l0: { cost: 1, parts: ["l1"] },
    l1: { cost: 2, parts: ["l2"] },
    l2: { cost: 4, parts: ["l3"] },
    l3: { cost: 8, parts: [] },
  };
  const catalog = createCatalog(deep);
  const tree = await resolveRecipe(catalog, "l0");
  assert.equal(tree.cost, 15);
  assert.equal(tree.parts[0].parts[0].parts[0].name, "l3");
  const names = [];
  for await (const name of expand(catalog, "l0")) names.push(name);
  assert.deepEqual(names, ["l0", "l1", "l2", "l3"]);
});
