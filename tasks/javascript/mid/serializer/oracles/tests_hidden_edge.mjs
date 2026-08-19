import test from "node:test";
import assert from "node:assert/strict";
import { encode, decode } from "./structured.mjs";

const roundTrip = (v) => decode(encode(v));

test("a self-referencing object round-trips", () => {
  const src = { name: "root" };
  src.self = src;
  const copy = roundTrip(src);
  assert.equal(copy.name, "root");
  assert.equal(copy.self, copy);
  assert.notEqual(copy, src);
});

test("mutual cycles round-trip", () => {
  const a = { name: "a" };
  const b = { name: "b", a };
  a.b = b;
  const copy = roundTrip(a);
  assert.equal(copy.b.a, copy);
  assert.equal(copy.b.name, "b");
});

test("an array containing itself round-trips", () => {
  const arr = [1];
  arr.push(arr);
  const copy = roundTrip(arr);
  assert.equal(copy[0], 1);
  assert.equal(copy[1], copy);
});

test("a Map that contains its own container round-trips", () => {
  const root = { name: "root" };
  root.index = new Map([["self", root]]);
  const copy = roundTrip(root);
  assert.equal(copy.index.get("self"), copy);
});

test("a Set that contains its own container round-trips", () => {
  const root = {};
  root.members = new Set([root, "x"]);
  const copy = roundTrip(root);
  assert.ok(copy.members.has(copy));
  assert.ok(copy.members.has("x"));
});

test("shared references decode into one shared object", () => {
  const shared = { hits: 0 };
  const src = { left: shared, right: shared, list: [shared] };
  const copy = roundTrip(src);
  assert.equal(copy.left, copy.right);
  assert.equal(copy.list[0], copy.left);
  copy.left.hits = 5;
  assert.equal(copy.right.hits, 5);
  assert.equal(shared.hits, 0);
});

test("a shared Date or Map stays shared", () => {
  const when = new Date(1000);
  const index = new Map([["k", "v"]]);
  const copy = roundTrip({ a: when, b: when, m1: index, m2: index });
  assert.equal(copy.a, copy.b);
  assert.equal(copy.m1, copy.m2);
  assert.equal(copy.a.getTime(), 1000);
});

test("map keys may be objects, and their identity is preserved", () => {
  const key = { id: 1 };
  const src = { index: new Map([[key, "value"]]), key };
  const copy = roundTrip(src);
  const copiedKey = [...copy.index.keys()][0];
  assert.deepEqual(copiedKey, { id: 1 });
  assert.notEqual(copiedKey, key);
  assert.equal(copiedKey, copy.key, "the same object is used as key and value");
  assert.equal(copy.index.get(copy.key), "value");
});

test("class instances decode as plain objects", () => {
  class Point {
    constructor(x, y) {
      this.x = x;
      this.y = y;
    }
  }
  const copy = roundTrip(new Point(1, 2));
  assert.deepEqual(copy, { x: 1, y: 2 });
  assert.equal(Object.getPrototypeOf(copy), Object.prototype);
  assert.equal(copy instanceof Point, false);
});

test("null-prototype objects decode as plain objects", () => {
  const src = Object.create(null);
  src.a = 1;
  const copy = roundTrip(src);
  assert.equal(copy.a, 1);
  assert.equal(Object.getPrototypeOf(copy), Object.prototype);
});

test("symbol-keyed properties are ignored", () => {
  const sym = Symbol("s");
  const src = { visible: 1, [sym]: "hidden" };
  const copy = roundTrip(src);
  assert.deepEqual(copy, { visible: 1 });
  assert.deepEqual(Object.getOwnPropertySymbols(copy), []);
});

test("functions and symbols are TypeErrors, wherever they hide", () => {
  assert.throws(() => encode(() => 1), TypeError);
  assert.throws(() => encode(Symbol("s")), TypeError);
  assert.throws(() => encode({ fn() {} }), TypeError);
  assert.throws(() => encode({ deep: { list: [1, () => 2] } }), TypeError);
  assert.throws(() => encode(new Map([["k", Symbol("s")]])), TypeError);
  assert.throws(() => encode(new Map([[() => 1, "v"]])), TypeError);
  assert.throws(() => encode(new Set([() => 1])), TypeError);
});

test("encoding is deterministic", () => {
  const src = { b: 1, a: new Map([["k", [1, 2]]]), when: new Date(5) };
  assert.equal(encode(src), encode(src));
  const cyclic = { n: 1 };
  cyclic.self = cyclic;
  assert.equal(encode(cyclic), encode(cyclic));
});

test("decode rejects a non-string", () => {
  for (const bad of [null, undefined, 1, {}, []]) {
    assert.throws(() => decode(bad), TypeError, String(bad));
  }
});

test("decode lets a JSON syntax error through", () => {
  assert.throws(() => decode("{not json"), SyntaxError);
  assert.throws(() => decode(""), SyntaxError);
});

test("deep nesting survives", () => {
  let node = { depth: 0 };
  const root = node;
  for (let i = 1; i <= 200; i++) {
    node.next = { depth: i };
    node = node.next;
  }
  const copy = roundTrip(root);
  let cursor = copy;
  let last = 0;
  while (cursor.next) {
    cursor = cursor.next;
    last = cursor.depth;
  }
  assert.equal(last, 200);
});

test("a wide structure survives", () => {
  const src = {};
  for (let i = 0; i < 200; i++) src[`k${i}`] = { i, tags: new Set([i]) };
  const copy = roundTrip(src);
  assert.equal(Object.keys(copy).length, 200);
  assert.equal(copy.k199.i, 199);
  assert.ok(copy.k0.tags.has(0));
});

test("strings that look like the format are still just strings", () => {
  const tricky = { a: '{"t":"date","v":0}', b: "[1,2]", c: '{"$ref":0}' };
  assert.deepEqual(roundTrip(tricky), tricky);
  assert.equal(typeof roundTrip(tricky).a, "string");
});
