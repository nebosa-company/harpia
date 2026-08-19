import test from "node:test";
import assert from "node:assert/strict";
import { deepClone } from "./deepclone.mjs";

test("a direct cycle is preserved", () => {
  const o = { name: "root" };
  o.self = o;
  const copy = deepClone(o);
  assert.notEqual(copy, o);
  assert.equal(copy.self, copy);
  assert.equal(copy.name, "root");
});

test("mutual cycles are preserved", () => {
  const a = { name: "a" };
  const b = { name: "b", a };
  a.b = b;
  const copy = deepClone(a);
  assert.equal(copy.b.a, copy);
  assert.notEqual(copy.b, b);
});

test("an array containing itself is preserved", () => {
  const arr = [1];
  arr.push(arr);
  const copy = deepClone(arr);
  assert.equal(copy[1], copy);
  assert.equal(copy[0], 1);
});

test("shared references stay shared", () => {
  const shared = { hits: 0 };
  const src = { left: shared, right: shared, list: [shared] };
  const copy = deepClone(src);
  assert.notEqual(copy.left, shared);
  assert.equal(copy.left, copy.right);
  assert.equal(copy.list[0], copy.left);
  copy.left.hits = 5;
  assert.equal(copy.right.hits, 5);
  assert.equal(shared.hits, 0);
});

test("cycles through a Map are preserved", () => {
  const root = { name: "root" };
  root.index = new Map([["self", root]]);
  const copy = deepClone(root);
  assert.ok(copy.index instanceof Map);
  assert.equal(copy.index.get("self"), copy);
});

test("map keys are cloned too", () => {
  const key = { id: 1 };
  const src = new Map([[key, "value"]]);
  const copy = deepClone(src);
  const copiedKey = [...copy.keys()][0];
  assert.notEqual(copiedKey, key);
  assert.deepEqual(copiedKey, { id: 1 });
  assert.equal(copy.get(copiedKey), "value");
  assert.equal(copy.get(key), undefined);
});

test("a Set containing the root is preserved", () => {
  const root = {};
  root.members = new Set([root, 1]);
  const copy = deepClone(root);
  assert.ok(copy.members.has(copy));
  assert.ok(copy.members.has(1));
  assert.equal(copy.members.has(root), false);
});

test("null-prototype objects stay null-prototype", () => {
  const src = Object.create(null);
  src.a = 1;
  src.nested = Object.create(null);
  src.nested.b = 2;
  const copy = deepClone(src);
  assert.equal(Object.getPrototypeOf(copy), null);
  assert.equal(Object.getPrototypeOf(copy.nested), null);
  assert.equal(copy.a, 1);
  assert.equal(copy.nested.b, 2);
});

test("class instances keep their prototype", () => {
  class Point {
    constructor(x, y) {
      this.x = x;
      this.y = y;
    }
    sum() {
      return this.x + this.y;
    }
  }
  const copy = deepClone(new Point(1, 2));
  assert.ok(copy instanceof Point);
  assert.equal(copy.sum(), 3);
  assert.equal(Object.getPrototypeOf(copy), Point.prototype);
});

test("symbol-keyed own enumerable properties are cloned", () => {
  const tag = Symbol("tag");
  const src = { [tag]: { deep: 1 } };
  const copy = deepClone(src);
  assert.deepEqual(copy[tag], { deep: 1 });
  assert.notEqual(copy[tag], src[tag]);
});

test("non-enumerable properties are skipped", () => {
  const src = { visible: 1 };
  Object.defineProperty(src, "hidden", { value: 2, enumerable: false });
  const copy = deepClone(src);
  assert.equal(copy.visible, 1);
  assert.equal(Object.hasOwn(copy, "hidden"), false);
});

test("getters are read once and stored as data properties", () => {
  let reads = 0;
  const src = {
    get computed() {
      reads += 1;
      return { n: 7 };
    },
  };
  const copy = deepClone(src);
  assert.equal(reads, 1);
  const desc = Object.getOwnPropertyDescriptor(copy, "computed");
  assert.equal(desc.get, undefined);
  assert.deepEqual(desc.value, { n: 7 });
  assert.equal(desc.writable, true);
  assert.equal(desc.enumerable, true);
  assert.equal(desc.configurable, true);
  assert.equal(reads, 1, "reading the clone must not call the source getter again");
});

test("deep nesting does not blow up", () => {
  let src = { depth: 0 };
  const root = src;
  for (let i = 1; i <= 200; i++) {
    src.next = { depth: i };
    src = src.next;
  }
  const copy = deepClone(root);
  let node = copy;
  let last = 0;
  while (node.next) {
    node = node.next;
    last = node.depth;
  }
  assert.equal(last, 200);
});
