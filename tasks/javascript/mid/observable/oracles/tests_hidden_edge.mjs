import test from "node:test";
import assert from "node:assert/strict";
import { observable, subscribe, raw } from "./observable.mjs";

test("delivery goes exact path first, then ancestors, then root", () => {
  const s = observable({ meta: { deep: { v: 1 } } });
  const order = [];
  subscribe(s, "", () => order.push("root"));
  subscribe(s, "meta", () => order.push("meta"));
  subscribe(s, "meta.deep", () => order.push("meta.deep"));
  subscribe(s, "meta.deep.v", () => order.push("exact-1"));
  subscribe(s, "meta.deep.v", () => order.push("exact-2"));
  s.meta.deep.v = 2;
  assert.deepEqual(order, ["exact-1", "exact-2", "meta.deep", "meta", "root"]);
});

test("every listener receives the same record", () => {
  const s = observable({ a: 1 });
  const records = [];
  subscribe(s, "", (c) => records.push(c));
  subscribe(s, "a", (c) => records.push(c));
  s.a = 2;
  assert.equal(records.length, 2);
  assert.deepEqual(records[0], { path: "a", kind: "set", value: 2, previous: 1 });
  assert.deepEqual(records[1], records[0]);
});

test("a listener registered during delivery does not see that change", () => {
  const s = observable({ a: 1 });
  const seen = [];
  let armed = true;
  subscribe(s, "", () => {
    if (!armed) return;
    armed = false;
    subscribe(s, "", () => seen.push("late"));
  });
  s.a = 2;
  assert.deepEqual(seen, []);
  s.a = 3;
  assert.deepEqual(seen, ["late"]);
});

test("push reports the new index once", () => {
  const s = observable({ items: [1, 2] });
  const seen = [];
  subscribe(s, "items", (c) => seen.push([c.path, c.kind, c.value, c.previous]));
  s.items.push(3);
  assert.deepEqual(seen, [["items.2", "set", 3, undefined]]);
  assert.deepEqual(raw(s).items, [1, 2, 3]);
});

test("pop reports the delete and the shorter length", () => {
  const s = observable({ items: [1, 2, 3] });
  const seen = [];
  subscribe(s, "", (c) => seen.push([c.path, c.kind, c.value, c.previous]));
  const popped = s.items.pop();
  assert.equal(popped, 3);
  assert.deepEqual(seen, [
    ["items.2", "delete", undefined, 3],
    ["items.length", "set", 2, 3],
  ]);
  assert.deepEqual(raw(s).items, [1, 2]);
});

test("assigning an object makes it observable in place", () => {
  const s = observable({});
  const seen = [];
  subscribe(s, "", (c) => seen.push(c.path));
  s.meta = { title: "one" };
  s.meta.title = "two";
  s.meta.tags = ["a"];
  s.meta.tags[0] = "b";
  assert.deepEqual(seen, ["meta", "meta.title", "meta.tags", "meta.tags.0"]);
  assert.deepEqual(raw(s), { meta: { title: "two", tags: ["b"] } });
});

test("replacing a subtree re-paths the new object", () => {
  const s = observable({ meta: { title: "old" } });
  const seen = [];
  subscribe(s, "meta.title", (c) => seen.push(c.value));
  s.meta = { title: "fresh" };
  s.meta.title = "changed";
  assert.deepEqual(seen, ["changed"]);
});

test("a proxy assigned into the tree is stored as its raw object", () => {
  const s = observable({ a: { n: 1 }, b: null });
  const seen = [];
  subscribe(s, "b", (c) => seen.push(c.value));
  s.b = s.a;
  assert.equal(raw(s).b, raw(s).a);
  assert.equal(seen[0], raw(s).a);
  assert.equal(Object.getPrototypeOf(seen[0]), Object.prototype);
  s.b.n = 5;
  assert.equal(raw(s).a.n, 5);
});

test("previous holds the raw object when a subtree is replaced", () => {
  const original = { n: 1 };
  const s = observable({ meta: original });
  const seen = [];
  subscribe(s, "meta", (c) => seen.push(c));
  s.meta = { n: 2 };
  assert.equal(seen[0].previous, original);
  assert.deepEqual(seen[0].value, { n: 2 });
});

test("symbol-keyed writes and deletes are never reported", () => {
  const key = Symbol("hidden");
  const s = observable({ a: 1 });
  const seen = [];
  subscribe(s, "", (c) => seen.push(c));
  s[key] = "value";
  assert.equal(s[key], "value");
  delete s[key];
  assert.deepEqual(seen, []);
});

test("an array root works and uses index paths", () => {
  const s = observable([1, 2]);
  const seen = [];
  subscribe(s, "", (c) => seen.push([c.path, c.value]));
  s[0] = 10;
  assert.deepEqual(seen, [["0", 10]]);
  assert.equal(Array.isArray(s), true);
  assert.deepEqual(raw(s), [10, 2]);
});

test("subscribing to a path that does not exist yet still works", () => {
  const s = observable({});
  const seen = [];
  subscribe(s, "future.value", (c) => seen.push(c.path));
  s.future = {};
  assert.deepEqual(seen, [], "the parent write is not below the subscribed path");
  s.future.value = 1;
  assert.deepEqual(seen, ["future.value"]);
});

test("a path prefix is not treated as an ancestor", () => {
  const s = observable({ item: { a: 1 }, items: { b: 2 } });
  const seen = [];
  subscribe(s, "item", (c) => seen.push(c.path));
  s.items.b = 3;
  assert.deepEqual(seen, []);
  s.item.a = 2;
  assert.deepEqual(seen, ["item.a"]);
});

test("several listeners on one path unsubscribe independently", () => {
  const s = observable({ a: 1 });
  const seen = [];
  const off1 = subscribe(s, "a", () => seen.push("one"));
  subscribe(s, "a", () => seen.push("two"));
  off1();
  s.a = 2;
  assert.deepEqual(seen, ["two"]);
});

test("observable rejects values it cannot wrap", () => {
  for (const bad of [null, undefined, 1, "s", true, new Date(), new Map(), () => {}]) {
    assert.throws(() => observable(bad), TypeError, String(bad));
  }
});

test("subscribe and raw reject non-observables", () => {
  const s = observable({ a: 1 });
  assert.throws(() => subscribe({}, "a", () => {}), TypeError);
  assert.throws(() => subscribe(null, "a", () => {}), TypeError);
  assert.throws(() => subscribe(s, 1, () => {}), TypeError);
  assert.throws(() => subscribe(s, "a", "not a function"), TypeError);
  assert.throws(() => raw({}), TypeError);
  assert.throws(() => raw(null), TypeError);
});

test("subscribing through a nested proxy uses root-relative paths", () => {
  const s = observable({ meta: { title: "old" } });
  const seen = [];
  subscribe(s.meta, "meta.title", (c) => seen.push(c.path));
  s.meta.title = "new";
  assert.deepEqual(seen, ["meta.title"]);
});

test("changes keep flowing after a listener throws nothing special", () => {
  const s = observable({ a: 1, b: 2 });
  const seen = [];
  subscribe(s, "a", (c) => seen.push(`a=${c.value}`));
  subscribe(s, "b", (c) => seen.push(`b=${c.value}`));
  s.a = 10;
  s.b = 20;
  s.a = 30;
  assert.deepEqual(seen, ["a=10", "b=20", "a=30"]);
});
