import { test } from "node:test";
import assert from "node:assert/strict";
import { createMachine, isValidTransition, reachableFrom } from "../src/machine";

const checkout = {
  idle: { start: "loading" },
  loading: { resolve: "ready", reject: "failed" },
  ready: { reset: "idle" },
  failed: { retry: "loading", reset: "idle" },
} as const;

test("a fresh machine sits in its initial state", () => {
  const m = createMachine(checkout, "idle");
  assert.equal(m.state, "idle");
  assert.deepEqual([...m.history], ["idle"]);
});

test("can answers for the current state only", () => {
  const m = createMachine(checkout, "idle");
  assert.equal(m.can("start"), true);
  assert.equal(m.can("resolve"), false);
  assert.equal(m.can("nonsense"), false);
  assert.equal(m.can("toString"), false, "prototype keys are not events");
  const loading = m.send("start");
  assert.equal(loading.can("resolve"), true);
  assert.equal(loading.can("start"), false);
});

test("send moves to the target state and records history", () => {
  const m = createMachine(checkout, "idle");
  const done = m.send("start").send("resolve");
  assert.equal(done.state, "ready");
  assert.deepEqual([...done.history], ["idle", "loading", "ready"]);
});

test("send leaves the receiver untouched", () => {
  const m = createMachine(checkout, "idle");
  const next = m.send("start");
  assert.equal(m.state, "idle");
  assert.deepEqual([...m.history], ["idle"]);
  assert.equal(next.state, "loading");
});

test("the same machine can be sent twice, independently", () => {
  const loading = createMachine(checkout, "loading");
  const ok = loading.send("resolve");
  const bad = loading.send("reject");
  assert.equal(ok.state, "ready");
  assert.equal(bad.state, "failed");
  assert.equal(loading.state, "loading");
});

test("a long walk keeps a full history", () => {
  const m = createMachine(checkout, "idle")
    .send("start")
    .send("reject")
    .send("retry")
    .send("resolve")
    .send("reset");
  assert.equal(m.state, "idle");
  assert.deepEqual([...m.history], [
    "idle",
    "loading",
    "failed",
    "loading",
    "ready",
    "idle",
  ]);
});

test("send throws when the transition is reached through a cast", () => {
  const m = createMachine(checkout, "idle") as unknown as {
    send(event: string): unknown;
  };
  assert.throws(
    () => m.send("resolve"),
    (err: unknown) =>
      err instanceof RangeError && err.message === "invalid transition: idle + resolve",
  );
});

test("isValidTransition works without a machine", () => {
  assert.equal(isValidTransition(checkout, "idle", "start"), true);
  assert.equal(isValidTransition(checkout, "idle", "resolve"), false);
  assert.equal(isValidTransition(checkout, "nowhere", "start"), false);
  assert.equal(isValidTransition(checkout, "failed", "reset"), true);
  assert.equal(isValidTransition(checkout, "ready", "toString"), false);
});

test("reachableFrom walks the whole graph", () => {
  assert.deepEqual(reachableFrom(checkout, "idle"), [
    "failed",
    "idle",
    "loading",
    "ready",
  ]);
  assert.deepEqual(reachableFrom(checkout, "ready"), [
    "failed",
    "idle",
    "loading",
    "ready",
  ]);
});

test("reachableFrom is empty for a terminal state", () => {
  const table = { a: { go: "b" }, b: {} };
  assert.deepEqual(reachableFrom(table, "b"), []);
  assert.deepEqual(reachableFrom(table, "a"), ["b"]);
});

test("reachableFrom includes the start only when a cycle returns to it", () => {
  const table = { a: { go: "b" }, b: { back: "a" } };
  assert.deepEqual(reachableFrom(table, "a"), ["a", "b"]);
  const linear = { a: { go: "b" }, b: { go: "c" }, c: {} };
  assert.deepEqual(reachableFrom(linear, "a"), ["b", "c"]);
});
