import test from "node:test";
import assert from "node:assert/strict";
import { deepClone } from "./deepclone.mjs";

test("primitives come back unchanged", () => {
  const sym = Symbol("s");
  assert.equal(deepClone(1), 1);
  assert.equal(deepClone("a"), "a");
  assert.equal(deepClone(true), true);
  assert.equal(deepClone(null), null);
  assert.equal(deepClone(undefined), undefined);
  assert.equal(deepClone(sym), sym);
  assert.equal(deepClone(10n), 10n);
  assert.ok(Number.isNaN(deepClone(NaN)));
});

test("functions are shared, not copied", () => {
  const fn = () => 1;
  assert.equal(deepClone(fn), fn);
  const clone = deepClone({ fn });
  assert.equal(clone.fn, fn);
});

test("plain objects are copied deeply and independently", () => {
  const src = { a: 1, nested: { b: 2, deeper: { c: 3 } } };
  const copy = deepClone(src);
  assert.deepEqual(copy, src);
  assert.notEqual(copy, src);
  assert.notEqual(copy.nested, src.nested);
  assert.notEqual(copy.nested.deeper, src.nested.deeper);
  copy.nested.deeper.c = 99;
  assert.equal(src.nested.deeper.c, 3);
});

test("arrays clone deeply", () => {
  const src = [1, [2, [3, { four: 4 }]]];
  const copy = deepClone(src);
  assert.ok(Array.isArray(copy));
  assert.deepEqual(copy, src);
  assert.notEqual(copy[1], src[1]);
  copy[1][1][1].four = 40;
  assert.equal(src[1][1][1].four, 4);
});

test("arrays nested in objects and vice versa", () => {
  const src = { list: [{ tags: ["a", "b"] }] };
  const copy = deepClone(src);
  assert.deepEqual(copy, src);
  copy.list[0].tags.push("c");
  assert.deepEqual(src.list[0].tags, ["a", "b"]);
});

test("dates clone into fresh equal dates", () => {
  const d = new Date(1700000000000);
  const copy = deepClone(d);
  assert.ok(copy instanceof Date);
  assert.notEqual(copy, d);
  assert.equal(copy.getTime(), d.getTime());
  const wrapped = deepClone({ when: d });
  assert.equal(wrapped.when.getTime(), d.getTime());
  assert.notEqual(wrapped.when, d);
});

test("regexps clone with source, flags and lastIndex", () => {
  const re = /ab+c/gi;
  re.lastIndex = 3;
  const copy = deepClone(re);
  assert.ok(copy instanceof RegExp);
  assert.notEqual(copy, re);
  assert.equal(copy.source, "ab+c");
  assert.equal(copy.flags, "gi");
  assert.equal(copy.lastIndex, 3);
});

test("maps clone keys and values in order", () => {
  const src = new Map([
    ["a", { n: 1 }],
    ["b", [1, 2]],
  ]);
  const copy = deepClone(src);
  assert.ok(copy instanceof Map);
  assert.notEqual(copy, src);
  assert.deepEqual([...copy.keys()], ["a", "b"]);
  assert.deepEqual(copy.get("a"), { n: 1 });
  assert.notEqual(copy.get("a"), src.get("a"));
  copy.get("b").push(3);
  assert.deepEqual(src.get("b"), [1, 2]);
});

test("sets clone values in order", () => {
  const inner = { n: 1 };
  const src = new Set([1, "two", inner]);
  const copy = deepClone(src);
  assert.ok(copy instanceof Set);
  assert.equal(copy.size, 3);
  assert.deepEqual([...copy].slice(0, 2), [1, "two"]);
  const copiedInner = [...copy][2];
  assert.deepEqual(copiedInner, { n: 1 });
  assert.notEqual(copiedInner, inner);
});

test("the source is never mutated", () => {
  const src = { a: [1, 2], m: new Map([["k", "v"]]), d: new Date(0) };
  const before = JSON.stringify({ a: src.a, k: src.m.get("k"), t: src.d.getTime() });
  deepClone(src);
  const after = JSON.stringify({ a: src.a, k: src.m.get("k"), t: src.d.getTime() });
  assert.equal(after, before);
});

test("empty containers clone", () => {
  assert.deepEqual(deepClone({}), {});
  assert.deepEqual(deepClone([]), []);
  assert.equal(deepClone(new Map()).size, 0);
  assert.equal(deepClone(new Set()).size, 0);
});
