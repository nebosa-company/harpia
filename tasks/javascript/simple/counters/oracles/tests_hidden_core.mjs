import test from "node:test";
import assert from "node:assert/strict";
import { makeCounters } from "./counters.mjs";

test("returns n independent functions", () => {
  const c = makeCounters(3);
  assert.equal(c.length, 3);
  assert.ok(Array.isArray(c));
  for (const fn of c) assert.equal(typeof fn, "function");
  assert.notEqual(c[0], c[1]);
});

test("each counter keeps its own running value", () => {
  const c = makeCounters(3);
  assert.equal(c[0](), 1);
  assert.equal(c[0](), 2);
  assert.equal(c[1](), 1);
  assert.equal(c[2](), 1);
  assert.equal(c[0](), 3);
  assert.equal(c[1](), 2);
  assert.equal(c[2](), 2);
});

test("counters from separate factory calls do not share state", () => {
  const a = makeCounters(2);
  const b = makeCounters(2);
  a[0]();
  a[0]();
  a[1]();
  assert.equal(b[0](), 1);
  assert.equal(b[1](), 1);
  assert.equal(a[0](), 3);
});

test("start offsets every counter equally and independently", () => {
  const c = makeCounters(3, 10);
  assert.equal(c[0](), 11);
  assert.equal(c[1](), 11);
  assert.equal(c[2](), 11);
  assert.equal(c[0](), 12);
  assert.equal(c[1](), 12);
});

test("negative and zero starts work", () => {
  const c = makeCounters(2, -5);
  assert.equal(c[0](), -4);
  assert.equal(c[1](), -4);
  assert.equal(makeCounters(1, 0)[0](), 1);
});

test("n === 0 yields an empty array", () => {
  assert.deepEqual(makeCounters(0), []);
  assert.deepEqual(makeCounters(0, 7), []);
});

test("a longer array stays fully independent", () => {
  const c = makeCounters(5);
  for (let i = 0; i < 5; i++) {
    for (let k = 0; k <= i; k++) c[i]();
  }
  assert.deepEqual(
    c.map((fn) => fn()),
    [2, 3, 4, 5, 6],
  );
});
