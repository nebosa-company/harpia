import test from "node:test";
import assert from "node:assert/strict";
import { encode, decode } from "./structured.mjs";

const roundTrip = (v) => decode(encode(v));

test("encode returns valid JSON text", () => {
  const text = encode({ a: 1, list: [1, "two", null], when: new Date(0) });
  assert.equal(typeof text, "string");
  assert.doesNotThrow(() => JSON.parse(text));
});

test("JSON primitives round-trip", () => {
  assert.equal(roundTrip("hello"), "hello");
  assert.equal(roundTrip(42), 42);
  assert.equal(roundTrip(-7.5), -7.5);
  assert.equal(roundTrip(true), true);
  assert.equal(roundTrip(false), false);
  assert.equal(roundTrip(null), null);
  assert.equal(roundTrip(""), "");
  assert.equal(roundTrip(0), 0);
});

test("undefined round-trips at the top level and inside containers", () => {
  assert.equal(roundTrip(undefined), undefined);
  const obj = roundTrip({ a: undefined, b: 1 });
  assert.equal(Object.hasOwn(obj, "a"), true);
  assert.equal(obj.a, undefined);
  assert.deepEqual(roundTrip([undefined, 1]), [undefined, 1]);
});

test("special numbers survive", () => {
  assert.ok(Number.isNaN(roundTrip(NaN)));
  assert.equal(roundTrip(Infinity), Infinity);
  assert.equal(roundTrip(-Infinity), -Infinity);
  assert.ok(Object.is(roundTrip(-0), -0));
  assert.ok(Object.is(roundTrip(0), 0));
  const wrapped = roundTrip({ nan: NaN, inf: Infinity, negZero: -0 });
  assert.ok(Number.isNaN(wrapped.nan));
  assert.equal(wrapped.inf, Infinity);
  assert.ok(Object.is(wrapped.negZero, -0));
});

test("bigints survive", () => {
  assert.equal(roundTrip(123n), 123n);
  assert.equal(roundTrip(-9007199254740993n), -9007199254740993n);
  assert.equal(roundTrip({ big: 10n }).big, 10n);
});

test("nested objects and arrays round-trip", () => {
  const src = { a: 1, nested: { b: [1, 2, { c: "deep" }] }, list: [[1], [2, [3]]] };
  assert.deepEqual(roundTrip(src), src);
});

test("object key order is preserved", () => {
  const src = { z: 1, a: 2, m: 3 };
  assert.deepEqual(Object.keys(roundTrip(src)), ["z", "a", "m"]);
});

test("dates round-trip", () => {
  const d = new Date(1700000000123);
  const copy = roundTrip(d);
  assert.ok(copy instanceof Date);
  assert.equal(copy.getTime(), d.getTime());
  assert.notEqual(copy, d);
  assert.equal(roundTrip({ when: d }).when.getTime(), d.getTime());
});

test("regexps round-trip", () => {
  const re = /ab+c/gim;
  const copy = roundTrip(re);
  assert.ok(copy instanceof RegExp);
  assert.equal(copy.source, "ab+c");
  assert.equal(copy.flags, re.flags);
  assert.equal(copy.test("abbc"), true);
});

test("maps round-trip with order and rich values", () => {
  const src = new Map([
    ["a", 1],
    ["b", { deep: true }],
    ["c", [1, 2]],
  ]);
  const copy = roundTrip(src);
  assert.ok(copy instanceof Map);
  assert.deepEqual([...copy.keys()], ["a", "b", "c"]);
  assert.deepEqual(copy.get("b"), { deep: true });
  assert.notEqual(copy.get("b"), src.get("b"));
});

test("sets round-trip with order", () => {
  const src = new Set([3, "two", { one: 1 }]);
  const copy = roundTrip(src);
  assert.ok(copy instanceof Set);
  assert.equal(copy.size, 3);
  assert.deepEqual([...copy].slice(0, 2), [3, "two"]);
  assert.deepEqual([...copy][2], { one: 1 });
});

test("maps and sets nest inside each other", () => {
  const src = { index: new Map([["tags", new Set(["a", "b"])]]) };
  const copy = roundTrip(src);
  assert.ok(copy.index.get("tags") instanceof Set);
  assert.deepEqual([...copy.index.get("tags")], ["a", "b"]);
});

test("empty containers round-trip", () => {
  assert.deepEqual(roundTrip({}), {});
  assert.deepEqual(roundTrip([]), []);
  assert.equal(roundTrip(new Map()).size, 0);
  assert.equal(roundTrip(new Set()).size, 0);
});

test("the decoded value shares nothing with the input", () => {
  const src = { list: [{ n: 1 }], map: new Map([["k", { n: 2 }]]), when: new Date(0) };
  const copy = roundTrip(src);
  assert.notEqual(copy, src);
  assert.notEqual(copy.list, src.list);
  assert.notEqual(copy.list[0], src.list[0]);
  assert.notEqual(copy.map, src.map);
  assert.notEqual(copy.map.get("k"), src.map.get("k"));
  assert.notEqual(copy.when, src.when);
  copy.list[0].n = 99;
  assert.equal(src.list[0].n, 1);
});

test("encode does not modify its input", () => {
  const src = { a: 1, list: [1, 2], map: new Map([["k", "v"]]) };
  const before = JSON.stringify({ a: src.a, list: src.list, k: src.map.get("k"), size: src.map.size });
  encode(src);
  const after = JSON.stringify({ a: src.a, list: src.list, k: src.map.get("k"), size: src.map.size });
  assert.equal(after, before);
  assert.deepEqual(Object.keys(src), ["a", "list", "map"]);
});

test("a mixed realistic payload survives", () => {
  const src = {
    id: 7n,
    created: new Date(86400000),
    tags: new Set(["a", "b"]),
    counts: new Map([
      ["x", 1],
      ["y", NaN],
    ]),
    nested: { list: [null, undefined, -0, Infinity], pattern: /a.c/i },
  };
  const copy = roundTrip(src);
  assert.equal(copy.id, 7n);
  assert.equal(copy.created.getTime(), 86400000);
  assert.deepEqual([...copy.tags], ["a", "b"]);
  assert.ok(Number.isNaN(copy.counts.get("y")));
  assert.equal(copy.nested.list[1], undefined);
  assert.ok(Object.is(copy.nested.list[2], -0));
  assert.equal(copy.nested.list[3], Infinity);
  assert.equal(copy.nested.pattern.source, "a.c");
  assert.equal(copy.nested.pattern.flags, "i");
});
