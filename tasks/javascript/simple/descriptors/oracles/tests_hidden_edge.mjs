import test from "node:test";
import assert from "node:assert/strict";
import { audit, sealValues, mirror, stripAccessors } from "./descriptors.mjs";

test("audit reports symbol keys as the symbols themselves", () => {
  const sym = Symbol("tag");
  const obj = { [sym]: 1 };
  const [record] = audit(obj);
  assert.equal(record.key, sym);
  assert.equal(typeof record.key, "symbol");
});

test("audit of an empty object is an empty array", () => {
  assert.deepEqual(audit({}), []);
  assert.deepEqual(audit(Object.create({ inherited: 1 })), []);
});

test("audit works on functions and arrays", () => {
  const keys = audit([1, 2]).map((r) => r.key);
  assert.deepEqual(keys, ["0", "1", "length"]);
  const fnKeys = audit(function named(a) {}).map((r) => r.key);
  assert.ok(fnKeys.includes("length"));
  assert.ok(fnKeys.includes("name"));
});

test("sealValues rejects a missing key and an accessor", () => {
  const obj = {
    a: 1,
    get computed() {
      return 2;
    },
  };
  assert.throws(() => sealValues(obj, ["nope"]), TypeError);
  assert.throws(() => sealValues(obj, ["computed"]), TypeError);
});

test("sealValues changes nothing when a key is invalid", () => {
  const obj = { a: 1, b: 2 };
  assert.throws(() => sealValues(obj, ["a", "missing"]), TypeError);
  obj.a = 9;
  assert.equal(obj.a, 9, "a must still be writable");
  assert.equal(Object.getOwnPropertyDescriptor(obj, "a").writable, true);
});

test("sealValues keeps a non-enumerable property non-enumerable", () => {
  const obj = {};
  Object.defineProperty(obj, "hidden", { value: 1, enumerable: false, writable: true, configurable: true });
  sealValues(obj, ["hidden"]);
  const desc = Object.getOwnPropertyDescriptor(obj, "hidden");
  assert.equal(desc.enumerable, false);
  assert.equal(desc.writable, false);
  assert.equal(desc.configurable, false);
});

test("sealValues handles symbol keys and an empty key list", () => {
  const sym = Symbol("k");
  const obj = { [sym]: 1, a: 2 };
  sealValues(obj, [sym]);
  assert.equal(Object.getOwnPropertyDescriptor(obj, sym).writable, false);
  assert.equal(sealValues(obj, []), obj);
  assert.equal(Object.getOwnPropertyDescriptor(obj, "a").writable, true);
});

test("mirror defines enumerable, configurable accessors", () => {
  const target = mirror({ a: 1 }, {}, ["a"]);
  const desc = Object.getOwnPropertyDescriptor(target, "a");
  assert.equal(typeof desc.get, "function");
  assert.equal(typeof desc.set, "function");
  assert.equal(desc.enumerable, true);
  assert.equal(desc.configurable, true);
  assert.deepEqual(Object.keys(target), ["a"]);
});

test("mirror handles keys the source does not have yet", () => {
  const source = {};
  const target = mirror(source, {}, ["later"]);
  assert.equal(target.later, undefined);
  target.later = "set";
  assert.equal(source.later, "set");
  assert.equal(target.later, "set");
});

test("mirror replaces an existing property on the target", () => {
  const source = { a: "from source" };
  const target = { a: "own" };
  mirror(source, target, ["a"]);
  assert.equal(target.a, "from source");
});

test("mirror does not copy values eagerly", () => {
  let reads = 0;
  const source = {
    get lazy() {
      reads += 1;
      return "value";
    },
  };
  const target = mirror(source, {}, ["lazy"]);
  assert.equal(reads, 0);
  assert.equal(target.lazy, "value");
  assert.equal(reads, 1);
});

test("mirror handles several keys and symbol keys", () => {
  const sym = Symbol("s");
  const source = { a: 1, [sym]: 2 };
  const target = mirror(source, {}, ["a", sym]);
  assert.equal(target.a, 1);
  assert.equal(target[sym], 2);
  target[sym] = 20;
  assert.equal(source[sym], 20);
});

test("stripAccessors preserves the prototype", () => {
  class Box {
    constructor(v) {
      this.v = v;
    }
    get doubled() {
      return this.v * 2;
    }
  }
  const box = new Box(3);
  box.own = { get x() { return 1; } };
  const out = stripAccessors(box);
  assert.equal(Object.getPrototypeOf(out), Box.prototype);
  assert.ok(out instanceof Box);
  assert.equal(out.v, 3);
  assert.equal(out.doubled, 6, "an inherited getter is untouched");
  assert.equal(Object.hasOwn(out, "doubled"), false);
});

test("stripAccessors preserves enumerability and symbol keys", () => {
  const sym = Symbol("s");
  const obj = { visible: 1, [sym]: 2 };
  Object.defineProperty(obj, "hidden", {
    get() {
      return 3;
    },
    enumerable: false,
    configurable: true,
  });
  const out = stripAccessors(obj);
  assert.deepEqual(Object.keys(out), ["visible"]);
  assert.equal(out.hidden, 3);
  assert.equal(Object.getOwnPropertyDescriptor(out, "hidden").enumerable, false);
  assert.equal(out[sym], 2);
});

test("stripAccessors yields undefined for a set-only accessor", () => {
  const written = [];
  const obj = {
    set only(v) {
      written.push(v);
    },
  };
  const out = stripAccessors(obj);
  assert.equal(Object.hasOwn(out, "only"), true);
  assert.equal(out.only, undefined);
  out.only = "no setter now";
  assert.equal(out.only, "no setter now");
  assert.deepEqual(written, []);
});

test("stripAccessors leaves the source object alone", () => {
  const obj = {
    get computed() {
      return 1;
    },
  };
  stripAccessors(obj);
  const desc = Object.getOwnPropertyDescriptor(obj, "computed");
  assert.equal(typeof desc.get, "function");
});

test("stripAccessors rejects non-objects", () => {
  for (const bad of [null, undefined, 3, "x"]) {
    assert.throws(() => stripAccessors(bad), TypeError, String(bad));
  }
});
