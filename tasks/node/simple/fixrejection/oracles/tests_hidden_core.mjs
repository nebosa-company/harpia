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

test("reports every outcome when a source fails mid-list", async () => {
  const sources = [
    { name: "alpha", read: async () => "A" },
    { name: "broken", read: async () => { throw new Error("disk on fire"); } },
    { name: "beta", read: async () => "B" },
    { name: "flaky", read: async () => { throw new Error("timeout"); } },
    { name: "gamma", read: async () => "C" },
  ];
  const out = await ingestAll(sources);
  assert.deepEqual(out.ok, [
    { name: "alpha", value: "A" },
    { name: "beta", value: "B" },
    { name: "gamma", value: "C" },
  ]);
  assert.deepEqual(out.failed, [
    { name: "broken", error: "disk on fire" },
    { name: "flaky", error: "timeout" },
  ]);
  await settle();
  assert.equal(unhandled.length, 0, "a rejection escaped ingestAll");
});

test("failure in the first source still reports the rest", async () => {
  const sources = [
    { name: "first", read: () => Promise.reject(new Error("boom")) },
    { name: "second", read: async () => 2 },
  ];
  const out = await ingestAll(sources);
  assert.deepEqual(out.ok, [{ name: "second", value: 2 }]);
  assert.deepEqual(out.failed, [{ name: "first", error: "boom" }]);
  await settle();
  assert.equal(unhandled.length, 0, "a rejection escaped ingestAll");
});

test("reads are started concurrently", async () => {
  let lastStarted = false;
  const waitForLast = () =>
    new Promise((resolve, reject) => {
      let spins = 0;
      const spin = () => {
        if (lastStarted) return resolve("first-value");
        if (++spins > 200) return reject(new Error("later sources never started"));
        setImmediate(spin);
      };
      spin();
    });
  const sources = [
    { name: "first", read: () => waitForLast() },
    { name: "last", read: async () => { lastStarted = true; return "last-value"; } },
  ];
  const out = await ingestAll(sources);
  assert.deepEqual(out.ok, [
    { name: "first", value: "first-value" },
    { name: "last", value: "last-value" },
  ]);
  assert.deepEqual(out.failed, []);
  await settle();
  assert.equal(unhandled.length, 0);
});
