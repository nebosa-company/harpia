import { test } from "node:test";
import assert from "node:assert/strict";
import { deepFreeze, isDeeplyFrozen } from "../src/deep-readonly";

test("non-objects come back unchanged and count as frozen", () => {
  assert.equal(deepFreeze(5), 5);
  assert.equal(deepFreeze("x"), "x");
  assert.equal(deepFreeze(null), null);
  assert.equal(deepFreeze(undefined), undefined);
  assert.equal(isDeeplyFrozen(5), true);
  assert.equal(isDeeplyFrozen("x"), true);
  assert.equal(isDeeplyFrozen(null), true);
  assert.equal(isDeeplyFrozen(undefined), true);
  assert.equal(isDeeplyFrozen(true), true);
});

test("deepFreeze returns the same object it was given", () => {
  const o = { a: 1 };
  assert.equal(deepFreeze(o), o);
});

test("nested objects are frozen all the way down", () => {
  const o = { a: { b: { c: 1 } }, d: 2 };
  deepFreeze(o);
  assert.equal(Object.isFrozen(o), true);
  assert.equal(Object.isFrozen(o.a), true);
  assert.equal(Object.isFrozen(o.a.b), true);
  assert.throws(() => {
    "use strict";
    (o.a.b as { c: number }).c = 9;
  });
  assert.equal(o.a.b.c, 1);
});

test("arrays and their elements are frozen", () => {
  const o = { rows: [{ n: 1 }, { n: 2 }] };
  deepFreeze(o);
  assert.equal(Object.isFrozen(o.rows), true);
  assert.equal(Object.isFrozen(o.rows[0]), true);
  assert.equal(Object.isFrozen(o.rows[1]), true);
  assert.throws(() => {
    "use strict";
    (o.rows as { n: number }[]).push({ n: 3 });
  });
});

test("functions are neither frozen nor descended into", () => {
  const fn = (): number => 1;
  (fn as unknown as { tag: { deep: number } }).tag = { deep: 1 };
  const o = { fn };
  deepFreeze(o);
  assert.equal(Object.isFrozen(o), true);
  assert.equal(Object.isFrozen(fn), false);
  assert.equal(isDeeplyFrozen(fn), true);
});

test("deepFreeze terminates on a cycle", () => {
  const a: { name: string; peer?: unknown } = { name: "a" };
  const b: { name: string; peer?: unknown } = { name: "b", peer: a };
  a.peer = b;
  deepFreeze(a);
  assert.equal(Object.isFrozen(a), true);
  assert.equal(Object.isFrozen(b), true);
});

test("isDeeplyFrozen is false while any level is still mutable", () => {
  const o = { a: { b: { c: 1 } } };
  assert.equal(isDeeplyFrozen(o), false);
  Object.freeze(o);
  assert.equal(isDeeplyFrozen(o), false);
  Object.freeze(o.a);
  assert.equal(isDeeplyFrozen(o), false);
  Object.freeze(o.a.b);
  assert.equal(isDeeplyFrozen(o), true);
});

test("isDeeplyFrozen agrees with deepFreeze", () => {
  const o = { a: [1, 2, { b: "x" }], c: { d: null } };
  assert.equal(isDeeplyFrozen(o), false);
  deepFreeze(o);
  assert.equal(isDeeplyFrozen(o), true);
});

test("isDeeplyFrozen terminates on a frozen cycle", () => {
  const a: { peer?: unknown } = {};
  const b: { peer?: unknown } = { peer: a };
  a.peer = b;
  deepFreeze(a);
  assert.equal(isDeeplyFrozen(a), true);
});

test("an already frozen branch is not re-entered", () => {
  const inner = { n: 1 };
  Object.freeze(inner);
  const outer = { inner, other: { n: 2 } };
  deepFreeze(outer);
  assert.equal(Object.isFrozen(outer.other), true);
  assert.equal(Object.isFrozen(inner), true);
});

test("empty containers are handled", () => {
  const o = { list: [] as unknown[], map: {} };
  deepFreeze(o);
  assert.equal(isDeeplyFrozen(o), true);
  assert.equal(Object.isFrozen(o.list), true);
  assert.equal(Object.isFrozen(o.map), true);
});
