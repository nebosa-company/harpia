import test from "node:test";
import assert from "node:assert/strict";
import { makeCounters, labelCounters } from "./counters.mjs";

test("labels carry each counter's own index", () => {
  const c = labelCounters(3);
  assert.equal(c[0](), "c0:1");
  assert.equal(c[1](), "c1:1");
  assert.equal(c[2](), "c2:1");
  assert.equal(c[0](), "c0:2");
  assert.equal(c[2](), "c2:2");
});

test("labelled counters honour start", () => {
  const c = labelCounters(2, 5);
  assert.equal(c[0](), "c0:6");
  assert.equal(c[1](), "c1:6");
  assert.equal(c[1](), "c1:7");
});

test("the last label of a longer array is not out of range", () => {
  const c = labelCounters(5);
  assert.equal(c[4](), "c4:1");
  assert.deepEqual(
    c.map((fn) => fn()),
    ["c0:1", "c1:1", "c2:1", "c3:1", "c4:2"],
  );
});

test("labelled arrays are independent of each other", () => {
  const a = labelCounters(2);
  const b = labelCounters(2);
  a[0]();
  a[0]();
  assert.equal(b[0](), "c0:1");
  assert.equal(a[0](), "c0:3");
});

test("labelCounters(0) is empty", () => {
  assert.deepEqual(labelCounters(0), []);
});

test("a bad n is a TypeError", () => {
  for (const bad of [-1, 1.5, "3", null, undefined, NaN, {}]) {
    assert.throws(() => makeCounters(bad), TypeError, `makeCounters(${String(bad)})`);
    assert.throws(() => labelCounters(bad), TypeError, `labelCounters(${String(bad)})`);
  }
});

test("a bad start is a TypeError", () => {
  for (const bad of ["0", null, NaN, Infinity, {}, true]) {
    assert.throws(() => makeCounters(2, bad), TypeError, `start=${String(bad)}`);
    assert.throws(() => labelCounters(2, bad), TypeError, `start=${String(bad)}`);
  }
});

test("counters take no arguments and ignore any that are passed", () => {
  const c = makeCounters(1);
  assert.equal(c[0](99), 1);
  assert.equal(c[0]("x"), 2);
});
