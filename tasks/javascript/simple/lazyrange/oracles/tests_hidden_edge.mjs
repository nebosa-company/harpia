import test from "node:test";
import assert from "node:assert/strict";
import { range } from "./range.mjs";

test("the iterator protocol is followed exactly", () => {
  const it = range(0, 2)[Symbol.iterator]();
  assert.deepEqual(it.next(), { value: 0, done: false });
  assert.deepEqual(it.next(), { value: 1, done: false });
  assert.deepEqual(it.next(), { value: undefined, done: true });
  assert.deepEqual(it.next(), { value: undefined, done: true });
});

test("an iterator is itself iterable", () => {
  const it = range(0, 3)[Symbol.iterator]();
  assert.equal(it[Symbol.iterator](), it);
  it.next();
  assert.deepEqual([...it], [1, 2]);
});

test("return() ends an iterator early", () => {
  const it = range(0, 5)[Symbol.iterator]();
  assert.equal(it.next().value, 0);
  assert.deepEqual(it.return(), { value: undefined, done: true });
  assert.deepEqual(it.next(), { value: undefined, done: true });
});

test("breaking out of a for..of leaves other walks unaffected", () => {
  const seq = range(0, 5);
  const seen = [];
  for (const v of seq) {
    seen.push(v);
    if (v === 2) break;
  }
  assert.deepEqual(seen, [0, 1, 2]);
  assert.deepEqual(seq.toArray(), [0, 1, 2, 3, 4]);
});

test("take stops pulling from its source", () => {
  let pulled = 0;
  const out = range(0, 100)
    .map((v) => {
      pulled += 1;
      return v;
    })
    .take(2)
    .toArray();
  assert.deepEqual(out, [0, 1]);
  assert.equal(pulled, 2);
});

test("filter only sees what is pulled", () => {
  let tested = 0;
  const out = range(0, 1000)
    .filter((v) => {
      tested += 1;
      return v % 5 === 0;
    })
    .take(2)
    .toArray();
  assert.deepEqual(out, [0, 5]);
  assert.equal(tested, 6);
});

test("nothing is evaluated before consumption", () => {
  let calls = 0;
  const seq = range(0, 10).map(() => {
    calls += 1;
    return 1;
  });
  assert.equal(calls, 0);
  seq.toArray();
  assert.equal(calls, 10);
});

test("derived sequences carry the same methods", () => {
  const derived = range(0, 10).map((v) => v);
  for (const name of ["map", "filter", "take", "toArray"]) {
    assert.equal(typeof derived[name], "function", name);
    assert.equal(typeof derived.filter(() => true)[name], "function", `filter.${name}`);
    assert.equal(typeof derived.take(1)[name], "function", `take.${name}`);
  }
  assert.equal(typeof derived[Symbol.iterator], "function");
});

test("a zero step is a RangeError", () => {
  assert.throws(() => range(0, 5, 0), RangeError);
});

test("non-finite arguments are a TypeError", () => {
  assert.throws(() => range("0", 5), TypeError);
  assert.throws(() => range(0, "5"), TypeError);
  assert.throws(() => range(0, 5, "1"), TypeError);
  assert.throws(() => range(0, Infinity), TypeError);
  assert.throws(() => range(NaN, 5), TypeError);
  assert.throws(() => range(null, 5), TypeError);
  assert.throws(() => range(0), TypeError);
});

test("bad combinator arguments are a TypeError", () => {
  const r = range(0, 5);
  assert.throws(() => r.take(-1), TypeError);
  assert.throws(() => r.take(1.5), TypeError);
  assert.throws(() => r.take("2"), TypeError);
  assert.throws(() => r.map(null), TypeError);
  assert.throws(() => r.filter("nope"), TypeError);
});

test("a huge descending range still takes cheaply", () => {
  const out = range(1e9, 0, -1).take(3).toArray();
  assert.deepEqual(out, [1e9, 1e9 - 1, 1e9 - 2]);
});

test("chained takes compose", () => {
  assert.deepEqual(range(0, 100).take(5).take(2).toArray(), [0, 1]);
  assert.deepEqual(range(0, 100).take(2).take(5).toArray(), [0, 1]);
});
