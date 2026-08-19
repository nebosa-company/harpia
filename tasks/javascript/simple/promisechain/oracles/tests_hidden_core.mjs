import test from "node:test";
import assert from "node:assert/strict";
import { runPipeline } from "./pipeline.mjs";

test("applies synchronous stages left to right", async () => {
  const out = await runPipeline(2, [(v) => v + 3, (v) => v * 10, (v) => `n=${v}`]);
  assert.equal(out, "n=50");
});

test("waits for asynchronous stages", async () => {
  const out = await runPipeline("a", [
    async (v) => v + "b",
    (v) => Promise.resolve(v + "c"),
    async (v) => v.toUpperCase(),
  ]);
  assert.equal(out, "ABC");
});

test("stages run in order, one after the other", async () => {
  const log = [];
  await runPipeline(0, [
    async (v) => {
      log.push("first-start");
      await null;
      log.push("first-end");
      return v + 1;
    },
    (v) => {
      log.push("second");
      return v + 1;
    },
  ]);
  assert.deepEqual(log, ["first-start", "first-end", "second"]);
});

test("an empty stage list returns the input", async () => {
  assert.equal(await runPipeline(7, []), 7);
  assert.equal(await runPipeline("x", []), "x");
});

test("returns a promise, never a bare value", () => {
  const result = runPipeline(1, []);
  assert.equal(typeof result.then, "function");
  return result;
});

test("a rejecting stage rejects the pipeline", async () => {
  await assert.rejects(
    async () => runPipeline(1, [() => Promise.reject(new Error("boom"))]),
    /boom/,
  );
});

test("a throwing stage rejects the pipeline", async () => {
  await assert.rejects(
    async () =>
      runPipeline(1, [
        (v) => v,
        () => {
          throw new RangeError("nope");
        },
      ]),
    RangeError,
  );
});

test("stages after a failure never run", async () => {
  const ran = [];
  await assert.rejects(
    async () =>
      runPipeline(1, [
        (v) => {
          ran.push("one");
          return v;
        },
        () => {
          throw new Error("stop");
        },
        (v) => {
          ran.push("three");
          return v;
        },
      ]),
    /stop/,
  );
  assert.deepEqual(ran, ["one"]);
});

test("a failing stage does not escape as an unhandled rejection", async () => {
  const seen = [];
  const onUnhandled = (reason) => seen.push(reason);
  process.on("unhandledRejection", onUnhandled);
  try {
    await assert.rejects(
      async () => runPipeline(1, [async () => { throw new Error("late"); }, (v) => v]),
      /late/,
    );
    await new Promise((resolve) => setImmediate(resolve));
    await new Promise((resolve) => setImmediate(resolve));
  } finally {
    process.off("unhandledRejection", onUnhandled);
  }
  assert.deepEqual(seen, [], "no rejection may go unhandled");
});

test("the rejection reason is passed through untouched", async () => {
  const reason = { code: "E_CUSTOM" };
  await assert.rejects(
    async () => runPipeline(1, [() => Promise.reject(reason)]),
    (err) => err === reason,
  );
});

test("side effects still happen while values flow through", async () => {
  const seen = [];
  const out = await runPipeline(1, [
    (v) => {
      seen.push(v);
      return v + 1;
    },
    (v) => {
      seen.push(v);
      return v + 1;
    },
  ]);
  assert.deepEqual(seen, [1, 2]);
  assert.equal(out, 3);
});
