import test from "node:test";
import assert from "node:assert/strict";
import { createDevice } from "./device.mjs";
import { openStore } from "./store.mjs";

test("put resolves with the written value and get round-trips", async () => {
  const store = openStore(createDevice());
  assert.equal(await store.put("alpha", 10), 10);
  assert.equal(await store.get("alpha"), 10);
});

test("get of a missing key rejects with NOT_FOUND", async () => {
  const store = openStore(createDevice());
  await assert.rejects(
    store.get("ghost"),
    (err) => err instanceof Error && err.code === "NOT_FOUND",
  );
});

test("remove deletes and missing removal rejects", async () => {
  const store = openStore(createDevice({ x: 1 }));
  assert.equal(await store.remove("x"), undefined);
  await assert.rejects(store.get("x"), (err) => err.code === "NOT_FOUND");
  await assert.rejects(store.remove("x"), (err) => err.code === "NOT_FOUND");
});

test("keys resolves with the sorted key list", async () => {
  const store = openStore(createDevice({ delta: 4, alpha: 1, charlie: 3 }));
  assert.deepEqual(await store.keys(), ["alpha", "charlie", "delta"]);
});

test("rename reads, writes, deletes in order", async () => {
  const device = createDevice({ old: "payload" });
  const store = openStore(device);
  assert.equal(await store.rename("old", "fresh"), undefined);
  assert.equal(await store.get("fresh"), "payload");
  await assert.rejects(store.get("old"), (err) => err.code === "NOT_FOUND");
});

test("rename of a missing key rejects and creates nothing", async () => {
  const store = openStore(createDevice({ other: 1 }));
  await assert.rejects(
    store.rename("ghost", "target"),
    (err) => err.code === "NOT_FOUND",
  );
  assert.deepEqual(await store.keys(), ["other"], "target must not exist");
});

test("total sums only numeric values", async () => {
  const store = openStore(
    createDevice({ a: 5, b: "text", c: 15, d: null, e: 2.5 }),
  );
  assert.equal(await store.total(), 22.5);
});

test("total of an empty device is 0", async () => {
  const store = openStore(createDevice());
  assert.equal(await store.total(), 0);
});
