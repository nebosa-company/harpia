import test from "node:test";
import assert from "node:assert/strict";
import { Emitter } from "./emitter.mjs";

test("handlers receive the emitted arguments", () => {
  const e = new Emitter();
  const seen = [];
  e.on("data", (...args) => seen.push(args));
  e.emit("data", 1, "two", { three: 3 });
  assert.deepEqual(seen, [[1, "two", { three: 3 }]]);
});

test("handlers run in registration order", () => {
  const e = new Emitter();
  const order = [];
  e.on("go", () => order.push("a"));
  e.on("go", () => order.push("b"));
  e.on("go", () => order.push("c"));
  e.emit("go");
  assert.deepEqual(order, ["a", "b", "c"]);
});

test("emit returns the number of handlers called", () => {
  const e = new Emitter();
  assert.equal(e.emit("nothing"), 0);
  e.on("x", () => {});
  e.on("x", () => {});
  assert.equal(e.emit("x"), 2);
  assert.equal(e.emit("y"), 0);
});

test("events are independent", () => {
  const e = new Emitter();
  const seen = [];
  e.on("a", () => seen.push("a"));
  e.on("b", () => seen.push("b"));
  e.emit("a");
  e.emit("a");
  e.emit("b");
  assert.deepEqual(seen, ["a", "a", "b"]);
});

test("the unsubscribe function stops the handler", () => {
  const e = new Emitter();
  const seen = [];
  const off = e.on("tick", () => seen.push(1));
  e.emit("tick");
  assert.equal(off(), true);
  e.emit("tick");
  assert.equal(off(), false);
  assert.deepEqual(seen, [1]);
  assert.equal(e.listenerCount("tick"), 0);
});

test("off removes a handler", () => {
  const e = new Emitter();
  const seen = [];
  const fn = () => seen.push(1);
  e.on("tick", fn);
  assert.equal(e.off("tick", fn), true);
  e.emit("tick");
  assert.deepEqual(seen, []);
  assert.equal(e.off("tick", fn), false);
  assert.equal(e.off("nope", fn), false);
});

test("once runs at most once", () => {
  const e = new Emitter();
  const seen = [];
  e.once("boot", (v) => seen.push(v));
  assert.equal(e.listenerCount("boot"), 1);
  assert.equal(e.emit("boot", "first"), 1);
  assert.equal(e.emit("boot", "second"), 0);
  assert.deepEqual(seen, ["first"]);
  assert.equal(e.listenerCount("boot"), 0);
});

test("once and on mix in registration order", () => {
  const e = new Emitter();
  const order = [];
  e.on("m", () => order.push("on1"));
  e.once("m", () => order.push("once"));
  e.on("m", () => order.push("on2"));
  e.emit("m");
  e.emit("m");
  assert.deepEqual(order, ["on1", "once", "on2", "on1", "on2"]);
});

test("listenerCount tracks registrations", () => {
  const e = new Emitter();
  assert.equal(e.listenerCount("x"), 0);
  const off = e.on("x", () => {});
  e.once("x", () => {});
  assert.equal(e.listenerCount("x"), 2);
  off();
  assert.equal(e.listenerCount("x"), 1);
});

test("this is bound to the emitter inside a handler", () => {
  const e = new Emitter();
  let self;
  e.on("who", function () {
    self = this;
  });
  e.emit("who");
  assert.equal(self, e);
});

test("events() lists the live events", () => {
  const e = new Emitter();
  assert.deepEqual(e.events(), []);
  const offA = e.on("a", () => {});
  e.on("b", () => {});
  assert.deepEqual(e.events(), ["a", "b"]);
  offA();
  assert.deepEqual(e.events(), ["b"]);
  e.on("a", () => {});
  assert.deepEqual(e.events(), ["b", "a"]);
});

test("two emitters do not share state", () => {
  const a = new Emitter();
  const b = new Emitter();
  const seen = [];
  a.on("x", () => seen.push("a"));
  b.on("x", () => seen.push("b"));
  a.emit("x");
  assert.deepEqual(seen, ["a"]);
  assert.equal(b.listenerCount("x"), 1);
});
