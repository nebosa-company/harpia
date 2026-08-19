import test from "node:test";
import assert from "node:assert/strict";
import { audit, sealValues, mirror, stripAccessors } from "./descriptors.mjs";

test("audit describes a plain data property", () => {
  const report = audit({ a: 1 });
  assert.deepEqual(report, [
    {
      key: "a",
      kind: "data",
      enumerable: true,
      configurable: true,
      writable: true,
      hasGetter: false,
      hasSetter: false,
    },
  ]);
});

test("audit describes accessors", () => {
  const obj = {
    get both() {
      return 1;
    },
    set both(v) {},
  };
  const [record] = audit(obj);
  assert.equal(record.kind, "accessor");
  assert.equal(record.writable, null);
  assert.equal(record.hasGetter, true);
  assert.equal(record.hasSetter, true);
  assert.equal(record.enumerable, true);
  assert.equal(record.configurable, true);
});

test("audit distinguishes get-only from set-only", () => {
  const getOnly = {
    get a() {
      return 1;
    },
  };
  const setOnly = {
    set b(v) {},
  };
  assert.deepEqual(
    audit(getOnly).map((r) => [r.hasGetter, r.hasSetter]),
    [[true, false]],
  );
  assert.deepEqual(
    audit(setOnly).map((r) => [r.hasGetter, r.hasSetter]),
    [[false, true]],
  );
});

test("audit never invokes a getter", () => {
  let reads = 0;
  const obj = {
    get expensive() {
      reads += 1;
      return 1;
    },
  };
  audit(obj);
  assert.equal(reads, 0);
});

test("audit includes non-enumerable properties and reports the flags", () => {
  const obj = {};
  Object.defineProperty(obj, "hidden", {
    value: 5,
    enumerable: false,
    writable: false,
    configurable: false,
  });
  const [record] = audit(obj);
  assert.equal(record.key, "hidden");
  assert.equal(record.enumerable, false);
  assert.equal(record.writable, false);
  assert.equal(record.configurable, false);
  assert.equal(record.kind, "data");
});

test("audit follows Reflect.ownKeys order and skips inherited properties", () => {
  const proto = { inherited: 1 };
  const obj = Object.create(proto);
  obj.b = 1;
  obj.a = 2;
  const sym = Symbol("s");
  obj[sym] = 3;
  assert.deepEqual(
    audit(obj).map((r) => r.key),
    ["b", "a", sym],
  );
});

test("audit rejects non-objects", () => {
  for (const bad of [null, undefined, 1, "s", true]) {
    assert.throws(() => audit(bad), TypeError, String(bad));
  }
});

test("sealValues locks the named properties", () => {
  const obj = { a: 1, b: 2 };
  const out = sealValues(obj, ["a"]);
  assert.equal(out, obj);
  const desc = Object.getOwnPropertyDescriptor(obj, "a");
  assert.equal(desc.writable, false);
  assert.equal(desc.configurable, false);
  assert.equal(desc.enumerable, true);
  assert.equal(desc.value, 1);
});

test("a sealed value cannot be written or deleted", () => {
  const obj = { a: 1, b: 2 };
  sealValues(obj, ["a"]);
  assert.throws(() => {
    obj.a = 9;
  }, TypeError);
  assert.throws(() => {
    delete obj.a;
  }, TypeError);
  assert.equal(obj.a, 1);
});

test("sealValues leaves other properties and extensibility alone", () => {
  const obj = { a: 1, b: 2 };
  sealValues(obj, ["a"]);
  obj.b = 20;
  assert.equal(obj.b, 20);
  obj.c = 3;
  assert.equal(obj.c, 3);
  assert.equal(Object.isExtensible(obj), true);
});

test("mirror reads through to the source", () => {
  const source = { a: 1, b: 2 };
  const target = {};
  const out = mirror(source, target, ["a", "b"]);
  assert.equal(out, target);
  assert.equal(target.a, 1);
  source.a = 42;
  assert.equal(target.a, 42);
});

test("mirror writes through to the source", () => {
  const source = { a: 1 };
  const target = mirror(source, {}, ["a"]);
  target.a = 7;
  assert.equal(source.a, 7);
  assert.equal(target.a, 7);
  assert.equal(Object.hasOwn(target, "a"), true);
});

test("stripAccessors turns getters into values", () => {
  const obj = {
    plain: 1,
    get computed() {
      return 2;
    },
  };
  const out = stripAccessors(obj);
  assert.notEqual(out, obj);
  assert.equal(out.plain, 1);
  assert.equal(out.computed, 2);
  const desc = Object.getOwnPropertyDescriptor(out, "computed");
  assert.equal(desc.get, undefined);
  assert.equal(desc.value, 2);
  assert.equal(desc.writable, true);
  assert.equal(desc.configurable, true);
});

test("stripAccessors calls each getter exactly once", () => {
  let reads = 0;
  const obj = {
    get once() {
      reads += 1;
      return reads;
    },
  };
  const out = stripAccessors(obj);
  assert.equal(reads, 1);
  assert.equal(out.once, 1);
  assert.equal(out.once, 1);
  assert.equal(reads, 1);
});
