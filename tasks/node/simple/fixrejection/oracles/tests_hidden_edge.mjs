import test from "node:test";
import assert from "node:assert/strict";
import { ingestAll } from "./ingest.mjs";

const unhandled = [];
process.on("unhandledRejection", (reason) => {
  unhandled.push(reason);
});

async function settle() {
  for (let i = 0; i < 20; i++) {
    await new Promise((r) => setImmediate(r));
  }
}

test("all sources failing still resolves with every failure", async () => {
  const sources = [
    { name: "a", read: async () => { throw new Error("a down"); } },
    { name: "b", read: () => Promise.reject(new Error("b down")) },
    { name: "c", read: async () => { throw "just a string"; } },
  ];
  const out = await ingestAll(sources);
  assert.deepEqual(out.ok, []);
  assert.deepEqual(out.failed, [
    { name: "a", error: "a down" },
    { name: "b", error: "b down" },
    { name: "c", error: "just a string" },
  ]);
  await settle();
  assert.equal(unhandled.length, 0, "a rejection escaped ingestAll");
});

test("non-Error rejection reasons are stringified", async () => {
  const out = await ingestAll([
    { name: "n", read: () => Promise.reject(42) },
  ]);
  assert.deepEqual(out.failed, [{ name: "n", error: "42" }]);
  await settle();
  assert.equal(unhandled.length, 0);
});

test("empty source list", async () => {
  assert.deepEqual(await ingestAll([]), { ok: [], failed: [] });
});

test("ingestAll never rejects", async () => {
  const p = ingestAll([
    { name: "x", read: () => Promise.reject(new Error("nope")) },
  ]);
  const out = await p; // must not throw
  assert.equal(out.failed.length, 1);
  await settle();
  assert.equal(unhandled.length, 0);
});
