import test from "node:test";
import assert from "node:assert/strict";
import { observable, subscribe, raw } from "./observable.mjs";

test("reading through the proxy is transparent", () => {
  const source = { a: 1, list: [1, 2], nested: { b: 2 } };
  const s = observable(source);
  assert.equal(s.a, 1);
  assert.deepEqual(Object.keys(s), ["a", "list", "nested"]);
  assert.equal("a" in s, true);
  assert.equal("missing" in s, false);
  assert.equal(Array.isArray(s.list), true);
  assert.equal(s.list.length, 2);
  assert.equal(JSON.stringify(s), JSON.stringify(source));
  assert.deepEqual({ ...s }.a, 1);
});

test("a top-level set is reported", () => {
  const s = observable({ a: 1 });
  const seen = [];
  subscribe(s, "a", (change) => seen.push(change));
  s.a = 2;
  assert.deepEqual(seen, [{ path: "a", kind: "set", value: 2, previous: 1 }]);
  assert.equal(s.a, 2);
});

test("a new property is reported with previous undefined", () => {
  const s = observable({});
  const seen = [];
  subscribe(s, "", (change) => seen.push(change));
  s.fresh = "value";
  assert.deepEqual(seen, [{ path: "fresh", kind: "set", value: "value", previous: undefined }]);
});

test("nested writes carry a dotted path", () => {
  const s = observable({ meta: { title: "old" } });
  const seen = [];
  subscribe(s, "meta.title", (change) => seen.push(change.path));
  s.meta.title = "new";
  assert.deepEqual(seen, ["meta.title"]);
  assert.equal(raw(s).meta.title, "new");
});

test("array elements use their index in the path", () => {
  const s = observable({ items: [1, 2, 3] });
  const seen = [];
  subscribe(s, "", (c) => seen.push([c.path, c.kind, c.value, c.previous]));
  s.items[1] = 20;
  assert.deepEqual(seen, [["items.1", "set", 20, 2]]);
  assert.deepEqual(raw(s).items, [1, 20, 3]);
});

test("a delete is reported", () => {
  const s = observable({ meta: { gone: 1, kept: 2 } });
  const seen = [];
  subscribe(s, "", (c) => seen.push(c));
  delete s.meta.gone;
  assert.deepEqual(seen, [{ path: "meta.gone", kind: "delete", value: undefined, previous: 1 }]);
  assert.deepEqual(Object.keys(raw(s).meta), ["kept"]);
});

test("writing the same value reports nothing", () => {
  const s = observable({ a: 1, o: null });
  const seen = [];
  subscribe(s, "", (c) => seen.push(c));
  s.a = 1;
  s.o = null;
  assert.deepEqual(seen, []);
  s.a = 2;
  assert.equal(seen.length, 1);
});

test("deleting a property that is not there reports nothing", () => {
  const s = observable({ a: 1 });
  const seen = [];
  subscribe(s, "", (c) => seen.push(c));
  delete s.missing;
  assert.deepEqual(seen, []);
});

test("nested proxies are cached", () => {
  const s = observable({ meta: { a: 1 }, items: [{ b: 2 }] });
  assert.equal(s.meta, s.meta);
  assert.equal(s.items[0], s.items[0]);
  assert.notEqual(s.meta, raw(s).meta);
});

test("raw returns the underlying objects", () => {
  const source = { meta: { a: 1 } };
  const s = observable(source);
  assert.equal(raw(s), source);
  assert.equal(raw(s.meta), source.meta);
});

test("non-plain values are handed back untouched", () => {
  const when = new Date(0);
  const index = new Map([["k", "v"]]);
  const fn = () => 1;
  class Thing {}
  const thing = new Thing();
  const s = observable({ when, index, fn, thing, n: null });
  assert.equal(s.when, when);
  assert.equal(s.index, index);
  assert.equal(s.fn, fn);
  assert.equal(s.thing, thing);
  assert.equal(s.n, null);
});

test("unsubscribing stops the listener", () => {
  const s = observable({ a: 1 });
  const seen = [];
  const off = subscribe(s, "a", (c) => seen.push(c.value));
  s.a = 2;
  assert.equal(off(), true);
  s.a = 3;
  assert.equal(off(), false);
  assert.deepEqual(seen, [2]);
});

test("a listener on an ancestor path hears descendant changes", () => {
  const s = observable({ meta: { deep: { value: 1 } } });
  const seen = [];
  subscribe(s, "meta", (c) => seen.push(c.path));
  s.meta.deep.value = 2;
  s.meta.other = 3;
  assert.deepEqual(seen, ["meta.deep.value", "meta.other"]);
});

test("a root listener hears everything", () => {
  const s = observable({ a: 1, meta: { b: 2 } });
  const seen = [];
  subscribe(s, "", (c) => seen.push(c.path));
  s.a = 10;
  s.meta.b = 20;
  assert.deepEqual(seen, ["a", "meta.b"]);
});

test("a listener on a sibling path hears nothing", () => {
  const s = observable({ left: { a: 1 }, right: { b: 2 } });
  const seen = [];
  subscribe(s, "left", (c) => seen.push(c.path));
  s.right.b = 20;
  assert.deepEqual(seen, []);
});

test("two observables are independent", () => {
  const a = observable({ v: 1 });
  const b = observable({ v: 1 });
  const seen = [];
  subscribe(a, "v", () => seen.push("a"));
  b.v = 2;
  assert.deepEqual(seen, []);
  a.v = 2;
  assert.deepEqual(seen, ["a"]);
});
