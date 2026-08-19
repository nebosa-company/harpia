import test from "node:test";
import assert from "node:assert/strict";
import { runPipeline, tap } from "./pipeline.mjs";

test("tap passes the original value through", async () => {
  const seen = [];
  const out = await runPipeline(5, [
    (v) => v * 2,
    tap((v) => seen.push(v)),
    (v) => v + 1,
  ]);
  assert.deepEqual(seen, [10]);
  assert.equal(out, 11);
});

test("tap ignores whatever its callback returns", async () => {
  const out = await runPipeline("keep", [tap(() => "discarded")]);
  assert.equal(out, "keep");
  const out2 = await runPipeline("keep", [tap(async () => "discarded")]);
  assert.equal(out2, "keep");
});

test("tap waits for an async callback before the next stage", async () => {
  const log = [];
  await runPipeline(1, [
    tap(async () => {
      log.push("audit-start");
      await null;
      await null;
      log.push("audit-end");
    }),
    (v) => {
      log.push("next-stage");
      return v;
    },
  ]);
  assert.deepEqual(log, ["audit-start", "audit-end", "next-stage"]);
});

test("a tap whose async callback rejects fails the pipeline", async () => {
  const after = [];
  await assert.rejects(
    async () =>
      runPipeline(1, [
        tap(async () => {
          throw new Error("audit failed");
        }),
        (v) => {
          after.push(v);
          return v;
        },
      ]),
    /audit failed/,
  );
  assert.deepEqual(after, []);
});

test("a tap whose callback throws synchronously fails the pipeline", async () => {
  await assert.rejects(
    async () =>
      runPipeline(1, [
        tap(() => {
          throw new TypeError("sync audit");
        }),
      ]),
    TypeError,
  );
});

test("tap rejects a non-function immediately", () => {
  for (const bad of [null, undefined, 1, "fn", {}]) {
    assert.throws(() => tap(bad), TypeError, `tap(${String(bad)})`);
  }
});

test("a promise input is awaited", async () => {
  const out = await runPipeline(Promise.resolve(4), [(v) => v * 2]);
  assert.equal(out, 8);
});

test("a thenable input is awaited", async () => {
  const thenable = {
    then(resolve) {
      resolve(3);
    },
  };
  assert.equal(await runPipeline(thenable, [(v) => v + 1]), 4);
  assert.equal(await runPipeline(thenable, []), 3);
});

test("a rejecting input rejects the pipeline", async () => {
  await assert.rejects(async () => runPipeline(Promise.reject(new Error("bad input")), []), /bad input/);
});

test("a stage may return a thenable", async () => {
  const out = await runPipeline(1, [
    (v) => ({
      then(resolve) {
        resolve(v + 41);
      },
    }),
  ]);
  assert.equal(out, 42);
});

test("undefined flows through like any other value", async () => {
  const seen = [];
  const out = await runPipeline(1, [() => undefined, tap((v) => seen.push(v))]);
  assert.equal(out, undefined);
  assert.deepEqual(seen, [undefined]);
});

test("a non-array stage list rejects with a TypeError", async () => {
  for (const bad of [null, undefined, 42, "stages", {}]) {
    await assert.rejects(async () => runPipeline(1, bad), TypeError, `stages=${String(bad)}`);
  }
});

test("a non-function stage rejects with a TypeError and stops the run", async () => {
  const ran = [];
  await assert.rejects(
    async () =>
      runPipeline(1, [
        (v) => {
          ran.push("one");
          return v;
        },
        "not a function",
        (v) => {
          ran.push("three");
          return v;
        },
      ]),
    TypeError,
  );
  assert.deepEqual(ran, ["one"]);
});

test("the stages array is not modified", async () => {
  const stages = [(v) => v + 1, (v) => v + 1];
  const copy = [...stages];
  await runPipeline(0, stages);
  assert.equal(stages.length, 2);
  assert.equal(stages[0], copy[0]);
  assert.equal(stages[1], copy[1]);
});

test("the same pipeline can be run twice", async () => {
  const stages = [(v) => v * 2];
  assert.equal(await runPipeline(2, stages), 4);
  assert.equal(await runPipeline(3, stages), 6);
});
