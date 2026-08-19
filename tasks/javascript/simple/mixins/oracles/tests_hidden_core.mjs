import test from "node:test";
import assert from "node:assert/strict";
import { mixin, layered, chainOf, classWith } from "./mixins.mjs";

test("mixin copies methods and returns the target", () => {
  const target = { own: 1 };
  const out = mixin(target, { hello() { return "hi"; } });
  assert.equal(out, target);
  assert.equal(target.hello(), "hi");
  assert.equal(target.own, 1);
});

test("later sources win", () => {
  const t = mixin({}, { a: 1, b: 1 }, { b: 2, c: 2 }, { c: 3 });
  assert.deepEqual({ ...t }, { a: 1, b: 2, c: 3 });
});

test("accessors stay accessors and are not invoked while copying", () => {
  let reads = 0;
  const source = {
    get computed() {
      reads += 1;
      return 42;
    },
  };
  const t = mixin({}, source);
  assert.equal(reads, 0, "getter must not run during the copy");
  const desc = Object.getOwnPropertyDescriptor(t, "computed");
  assert.equal(typeof desc.get, "function");
  assert.equal(desc.value, undefined);
  assert.equal(t.computed, 42);
  assert.equal(reads, 1);
});

test("setters survive the copy", () => {
  const seen = [];
  const source = {
    set track(v) {
      seen.push(v);
    },
  };
  const t = mixin({}, source);
  t.track = "x";
  assert.deepEqual(seen, ["x"]);
});

test("enumerable / writable / configurable flags are preserved", () => {
  const source = {};
  Object.defineProperty(source, "hidden", {
    value: 7,
    enumerable: false,
    writable: false,
    configurable: true,
  });
  const t = mixin({}, source);
  const desc = Object.getOwnPropertyDescriptor(t, "hidden");
  assert.deepEqual(desc, { value: 7, enumerable: false, writable: false, configurable: true });
  assert.deepEqual(Object.keys(t), []);
});

test("mixin does not mutate its sources", () => {
  const source = { a: 1 };
  const t = mixin({ b: 2 }, source);
  assert.deepEqual(source, { a: 1 });
  assert.equal(t.b, 2);
});

test("layered builds one prototype layer per mixin", () => {
  const base = { kind: "base", tag() { return "base"; } };
  const walks = { walk() { return "walking"; } };
  const swims = { swim() { return "swimming"; }, tag() { return "swimmer"; } };
  const obj = layered(base, walks, swims);

  assert.deepEqual(Object.keys(obj), [], "the returned object owns nothing");
  assert.equal(obj.walk(), "walking");
  assert.equal(obj.swim(), "swimming");
  assert.equal(obj.tag(), "swimmer", "the topmost layer wins");
  assert.equal(obj.kind, "base");

  const chain = chainOf(obj);
  assert.ok(Object.hasOwn(chain[0], "swim"));
  assert.ok(!Object.hasOwn(chain[0], "walk"));
  assert.ok(Object.hasOwn(chain[1], "walk"));
  assert.equal(chain[2], base);
});

test("layered leaves base and the mixin objects alone", () => {
  const base = { kind: "base" };
  const m = { walk() { return 1; } };
  const obj = layered(base, m);
  assert.deepEqual(Object.keys(base), ["kind"]);
  assert.equal(Object.getPrototypeOf(obj) === m, false, "layers are fresh objects, not the mixins");
  assert.equal(chainOf(obj).includes(m), false);
});

test("chainOf walks up to Object.prototype", () => {
  const chain = chainOf({});
  assert.deepEqual(chain, [Object.prototype]);
  const child = Object.create({ a: 1 });
  assert.equal(chainOf(child).length, 2);
  assert.equal(chainOf(child)[1], Object.prototype);
});

test("classWith produces a subclass carrying the mixins", () => {
  class Animal {
    constructor(name) {
      this.name = name;
    }
    speak() {
      return `${this.name} makes a sound`;
    }
    legs() {
      return 4;
    }
  }
  const Barks = {
    speak() {
      return `${this.name} barks`;
    },
    fetch() {
      return "fetching";
    },
  };
  const Dog = classWith(Animal, Barks);
  const rex = new Dog("Rex");
  assert.ok(rex instanceof Dog);
  assert.ok(rex instanceof Animal);
  assert.equal(rex.speak(), "Rex barks");
  assert.equal(rex.fetch(), "fetching");
  assert.equal(rex.legs(), 4);
  assert.equal(new Animal("Kit").speak(), "Kit makes a sound", "Animal is untouched");
  assert.equal(Object.hasOwn(Animal.prototype, "fetch"), false);
});
