import test from "node:test";
import assert from "node:assert/strict";
import { mixin, layered, chainOf, classWith } from "./mixins.mjs";

test("symbol keys are copied", () => {
  const tag = Symbol("tag");
  const t = mixin({}, { [tag]: "marked" });
  assert.equal(t[tag], "marked");
  assert.deepEqual(Object.getOwnPropertySymbols(t), [tag]);
});

test("the constructor key is never copied", () => {
  class Foo {
    hello() {
      return "foo";
    }
  }
  const t = {};
  mixin(t, Foo.prototype);
  assert.equal(t.hello(), "foo");
  assert.equal(Object.hasOwn(t, "constructor"), false);
  assert.equal(t.constructor, Object);
});

test("a non-object target is a TypeError", () => {
  for (const bad of [null, undefined, 1, "s", true]) {
    assert.throws(() => mixin(bad, { a: 1 }), TypeError, `target=${String(bad)}`);
  }
});

test("null and undefined sources are ignored", () => {
  const t = mixin({}, null, { a: 1 }, undefined);
  assert.deepEqual(t, { a: 1 });
  assert.deepEqual(mixin({ a: 1 }), { a: 1 });
});

test("layered with no mixins still returns a fresh empty object", () => {
  const base = { a: 1 };
  const obj = layered(base);
  assert.notEqual(obj, base);
  assert.deepEqual(Object.keys(obj), []);
  assert.equal(Object.getPrototypeOf(obj), base);
  assert.equal(obj.a, 1);
});

test("layered accepts a null base", () => {
  const obj = layered(null, { a() { return 1; } });
  assert.equal(obj.a(), 1);
  assert.equal(chainOf(obj).length, 1);
  assert.equal(Object.getPrototypeOf(chainOf(obj)[0]), null);
  assert.equal(obj.toString, undefined, "no Object.prototype in this chain");
});

test("layered with a null base and no mixins has an empty chain", () => {
  const obj = layered(null);
  assert.deepEqual(chainOf(obj), []);
});

test("layered preserves accessors per layer without invoking them", () => {
  let reads = 0;
  const obj = layered(
    { base: true },
    {
      get value() {
        reads += 1;
        return "lazy";
      },
    },
  );
  assert.equal(reads, 0);
  assert.equal(obj.value, "lazy");
  assert.equal(reads, 1);
  assert.equal(Object.hasOwn(obj, "value"), false);
});

test("writing to a layered object shadows rather than mutating the layer", () => {
  const obj = layered({ a: 1 }, { b: 2 });
  obj.b = 99;
  assert.ok(Object.hasOwn(obj, "b"));
  assert.equal(chainOf(obj)[0].b, 2);
});

test("chainOf of a class instance lists prototype then Object.prototype", () => {
  class A {}
  class B extends A {}
  const chain = chainOf(new B());
  assert.equal(chain[0], B.prototype);
  assert.equal(chain[1], A.prototype);
  assert.equal(chain[2], Object.prototype);
  assert.equal(chain.length, 3);
});

test("chainOf a null-prototype object is empty", () => {
  assert.deepEqual(chainOf(Object.create(null)), []);
});

test("classWith forwards constructor args and keeps the original reachable", () => {
  class Base {
    constructor(a, b) {
      this.sum = a + b;
    }
    label() {
      return "base";
    }
  }
  const Loud = {
    label() {
      return Base.prototype.label.call(this).toUpperCase();
    },
  };
  const Mixed = classWith(Base, Loud);
  const m = new Mixed(2, 3);
  assert.equal(m.sum, 5, "constructor args reach Base");
  assert.equal(m.label(), "BASE");
  assert.equal(Mixed.prototype.constructor, Mixed);
  assert.equal(Object.getPrototypeOf(Mixed.prototype), Base.prototype);
});

test("classWith with several mixins applies them left to right", () => {
  class Base {
    who() {
      return "base";
    }
  }
  const A = { who() { return "a"; }, a: 1 };
  const B = { who() { return "b"; } };
  const M = classWith(Base, A, B);
  const m = new M();
  assert.equal(m.who(), "b");
  assert.equal(m.a, 1);
  assert.equal(new Base().who(), "base");
});

test("classWith with no mixins is still a working subclass", () => {
  class Base {
    hi() {
      return "hi";
    }
  }
  const Sub = classWith(Base);
  assert.notEqual(Sub, Base);
  assert.equal(new Sub().hi(), "hi");
  assert.ok(new Sub() instanceof Base);
});
