import test from "node:test";
import assert from "node:assert/strict";
import { Emitter } from "./emitter.mjs";

test("the same handler registered twice runs twice", () => {
  const e = new Emitter();
  let calls = 0;
  const fn = () => {
    calls += 1;
  };
  e.on("x", fn);
  e.on("x", fn);
  assert.equal(e.listenerCount("x"), 2);
  assert.equal(e.emit("x"), 2);
  assert.equal(calls, 2);
});

test("off removes only the earliest duplicate registration", () => {
  const e = new Emitter();
  let calls = 0;
  const fn = () => {
    calls += 1;
  };
  e.on("x", fn);
  e.on("x", fn);
  assert.equal(e.off("x", fn), true);
  assert.equal(e.listenerCount("x"), 1);
  e.emit("x");
  assert.equal(calls, 1);
});

test("each unsubscribe function removes only its own registration", () => {
  const e = new Emitter();
  const fn = () => {};
  const off1 = e.on("x", fn);
  e.on("x", fn);
  assert.equal(off1(), true);
  assert.equal(off1(), false);
  assert.equal(e.listenerCount("x"), 1);
});

test("a handler added during an emit is not called by that emit", () => {
  const e = new Emitter();
  const order = [];
  e.on("x", () => {
    order.push("first");
    e.on("x", () => order.push("added"));
  });
  assert.equal(e.emit("x"), 1);
  assert.deepEqual(order, ["first"]);
  e.emit("x");
  assert.deepEqual(order, ["first", "first", "added"]);
});

test("a handler removed during an emit is skipped", () => {
  const e = new Emitter();
  const order = [];
  const second = () => order.push("second");
  e.on("x", () => {
    order.push("first");
    e.off("x", second);
  });
  e.on("x", second);
  e.on("x", () => order.push("third"));
  assert.equal(e.emit("x"), 2);
  assert.deepEqual(order, ["first", "third"]);
});

test("a once handler is removed before it runs", () => {
  const e = new Emitter();
  const order = [];
  e.once("x", () => {
    order.push("once");
    e.emit("x");
  });
  e.emit("x");
  assert.deepEqual(order, ["once"]);
});

test("removing a once registration before it fires works", () => {
  const e = new Emitter();
  let calls = 0;
  const fn = () => {
    calls += 1;
  };
  e.once("x", fn);
  assert.equal(e.off("x", fn), true);
  assert.equal(e.emit("x"), 0);
  assert.equal(calls, 0);
});

test("every handler runs even when one throws, and the first error surfaces", () => {
  const e = new Emitter();
  const order = [];
  e.on("x", () => {
    order.push("a");
    throw new Error("first failure");
  });
  e.on("x", () => {
    order.push("b");
    throw new Error("second failure");
  });
  e.on("x", () => order.push("c"));
  assert.throws(() => e.emit("x"), /first failure/);
  assert.deepEqual(order, ["a", "b", "c"]);
});

test("a throwing once handler is still removed", () => {
  const e = new Emitter();
  e.once("x", () => {
    throw new Error("boom");
  });
  assert.throws(() => e.emit("x"), /boom/);
  assert.equal(e.listenerCount("x"), 0);
  assert.equal(e.emit("x"), 0);
});

test("symbol event names work", () => {
  const e = new Emitter();
  const key = Symbol("secret");
  const seen = [];
  e.on(key, (v) => seen.push(v));
  assert.equal(e.emit(key, 1), 1);
  assert.deepEqual(seen, [1]);
  assert.deepEqual(e.events(), [key]);
  assert.equal(e.listenerCount(key), 1);
});

test("bad event names and handlers are TypeErrors", () => {
  const e = new Emitter();
  for (const bad of [null, undefined, 1, {}, true]) {
    assert.throws(() => e.on(bad, () => {}), TypeError, `on(${String(bad)})`);
    assert.throws(() => e.once(bad, () => {}), TypeError, `once(${String(bad)})`);
    assert.throws(() => e.emit(bad), TypeError, `emit(${String(bad)})`);
  }
  for (const bad of [null, undefined, 1, "fn", {}]) {
    assert.throws(() => e.on("x", bad), TypeError, `handler=${String(bad)}`);
    assert.throws(() => e.once("x", bad), TypeError, `handler=${String(bad)}`);
  }
});

test("re-entrant emit of another event works", () => {
  const e = new Emitter();
  const order = [];
  e.on("outer", () => {
    order.push("outer");
    e.emit("inner");
  });
  e.on("inner", () => order.push("inner"));
  e.emit("outer");
  assert.deepEqual(order, ["outer", "inner"]);
});

test("an event with no listeners disappears from events()", () => {
  const e = new Emitter();
  const off = e.once("x", () => {});
  assert.deepEqual(e.events(), ["x"]);
  e.emit("x");
  assert.deepEqual(e.events(), []);
  assert.equal(off(), false);
});
