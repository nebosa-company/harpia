import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createDevice } from "./device.mjs";
import { openStore } from "./store.mjs";

test("every method returns a real Promise", async () => {
  const store = openStore(createDevice({ a: 1 }));
  const gp = store.get("a");
  assert.ok(gp instanceof Promise, "get must return a Promise");
  await gp;
  const pp = store.put("b", 2);
  assert.ok(pp instanceof Promise, "put must return a Promise");
  await pp;
  const kp = store.keys();
  assert.ok(kp instanceof Promise, "keys must return a Promise");
  await kp;
  const rp = store.rename("b", "c");
  assert.ok(rp instanceof Promise, "rename must return a Promise");
  await rp;
  const dp = store.remove("c");
  assert.ok(dp instanceof Promise, "remove must return a Promise");
  await dp;
  const tp = store.total();
  assert.ok(tp instanceof Promise, "total must return a Promise");
  await tp;
});

test("methods no longer declare a callback parameter", () => {
  const store = openStore(createDevice());
  assert.equal(store.get.length, 1, "get(key)");
  assert.equal(store.put.length, 2, "put(key, value)");
  assert.equal(store.remove.length, 1, "remove(key)");
  assert.equal(store.keys.length, 0, "keys()");
  assert.equal(store.rename.length, 2, "rename(oldKey, newKey)");
  assert.equal(store.total.length, 0, "total()");
});

test("store.mjs actually uses async/await", async () => {
  const src = await readFile(new URL("./store.mjs", import.meta.url), "utf8");
  assert.match(src, /\basync\b/, "expected async in store.mjs");
  assert.match(src, /\bawait\b/, "expected await in store.mjs");
});

test("rejections carry the device error code", async () => {
  const store = openStore(createDevice());
  const p = store.get("missing");
  assert.ok(p instanceof Promise);
  await assert.rejects(p, (err) => err.code === "NOT_FOUND");
});
