import test from "node:test";
import assert from "node:assert/strict";
import { createDevice } from "../device.mjs";
import { openStore } from "../store.mjs";

// Invokes a store method regardless of API style: works for error-first
// callback methods and for promise-returning methods alike, so this suite
// keeps passing across the planned API migration.
function invoke(fn, ...args) {
  return new Promise((resolve, reject) => {
    let settled = false;
    const done = (err, value) => {
      if (settled) return;
      settled = true;
      if (err) reject(err);
      else resolve(value);
    };
    const out = fn(...args, done);
    if (out && typeof out.then === "function") {
      out.then(
        (v) => done(null, v),
        (e) => done(e),
      );
    }
  });
}

test("put then get round-trips", async () => {
  const store = openStore(createDevice());
  await invoke(store.put, "alpha", 10);
  assert.equal(await invoke(store.get, "alpha"), 10);
});

test("get of a missing key fails with NOT_FOUND", async () => {
  const store = openStore(createDevice());
  await assert.rejects(
    invoke(store.get, "ghost"),
    (err) => err.code === "NOT_FOUND",
  );
});

test("keys lists sorted keys", async () => {
  const store = openStore(createDevice({ b: 2, a: 1, c: 3 }));
  assert.deepEqual(await invoke(store.keys), ["a", "b", "c"]);
});

test("rename moves a value", async () => {
  const store = openStore(createDevice({ old: "v" }));
  await invoke(store.rename, "old", "fresh");
  assert.equal(await invoke(store.get, "fresh"), "v");
  await assert.rejects(
    invoke(store.get, "old"),
    (err) => err.code === "NOT_FOUND",
  );
});

test("total sums numeric values", async () => {
  const store = openStore(
    createDevice({ a: 1, b: 2, note: "not a number", c: 4 }),
  );
  assert.equal(await invoke(store.total), 7);
});
