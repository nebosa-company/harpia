import test from "node:test";
import assert from "node:assert/strict";
import { range } from "./range.mjs";

test("produces the half-open interval", () => {
  assert.deepEqual(range(0, 5).toArray(), [0, 1, 2, 3, 4]);
  assert.deepEqual(range(2, 6).toArray(), [2, 3, 4, 5]);
  assert.deepEqual([...range(0, 3)], [0, 1, 2]);
});

test("is not an array", () => {
  const r = range(0, 3);
  assert.equal(Array.isArray(r), false);
  assert.equal(r.length, undefined);
  assert.ok(Array.isArray(r.toArray()));
});

test("honours a step", () => {
  assert.deepEqual(range(0, 10, 3).toArray(), [0, 3, 6, 9]);
  assert.deepEqual(range(1, 2, 0.25).toArray(), [1, 1.25, 1.5, 1.75]);
});

test("counts down with a negative step", () => {
  assert.deepEqual(range(5, 0, -1).toArray(), [5, 4, 3, 2, 1]);
  assert.deepEqual(range(10, 0, -4).toArray(), [10, 6, 2]);
});

test("empty ranges are empty", () => {
  assert.deepEqual(range(5, 5).toArray(), []);
  assert.deepEqual(range(5, 0).toArray(), []);
  assert.deepEqual(range(0, 5, -1).toArray(), []);
  assert.deepEqual([...range(3, 3)], []);
});

test("works with for..of", () => {
  const seen = [];
  for (const v of range(0, 4)) seen.push(v);
  assert.deepEqual(seen, [0, 1, 2, 3]);
});

test("map transforms lazily and passes an index", () => {
  const pairs = range(10, 13)
    .map((v, i) => `${i}:${v}`)
    .toArray();
  assert.deepEqual(pairs, ["0:10", "1:11", "2:12"]);
});

test("filter keeps matching values and counts its own index", () => {
  assert.deepEqual(range(0, 10).filter((v) => v % 3 === 0).toArray(), [0, 3, 6, 9]);
  assert.deepEqual(range(0, 5).filter((v, i) => i % 2 === 0).toArray(), [0, 2, 4]);
});

test("take limits the sequence", () => {
  assert.deepEqual(range(0, 100).take(4).toArray(), [0, 1, 2, 3]);
  assert.deepEqual(range(0, 2).take(10).toArray(), [0, 1]);
  assert.deepEqual(range(0, 100).take(0).toArray(), []);
});

test("combinators chain and stay lazy", () => {
  const out = range(0, 1_000_000)
    .filter((v) => v % 2 === 0)
    .map((v) => v * 10)
    .take(4)
    .toArray();
  assert.deepEqual(out, [0, 20, 40, 60]);
});

test("a giant range is cheap when only a few values are pulled", () => {
  let calls = 0;
  const out = range(0, 1e9)
    .map((v) => {
      calls += 1;
      return v + 1;
    })
    .take(3)
    .toArray();
  assert.deepEqual(out, [1, 2, 3]);
  assert.equal(calls, 3);
});

test("sequences are re-iterable", () => {
  const seq = range(0, 4).map((v) => v * 2);
  assert.deepEqual(seq.toArray(), [0, 2, 4, 6]);
  assert.deepEqual(seq.toArray(), [0, 2, 4, 6]);
  assert.deepEqual([...seq], [0, 2, 4, 6]);
  const a = seq[Symbol.iterator]();
  const b = seq[Symbol.iterator]();
  assert.notEqual(a, b);
  assert.equal(a.next().value, 0);
  assert.equal(b.next().value, 0);
});
