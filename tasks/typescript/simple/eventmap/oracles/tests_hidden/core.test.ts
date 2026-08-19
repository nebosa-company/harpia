import { test } from "node:test";
import assert from "node:assert/strict";
import { createEmitter } from "../src/emitter";

type Events = {
  saved: { id: string; size: number };
  closed: void;
  tick: number;
};

test("on delivers the payload and emit counts the listeners", () => {
  const e = createEmitter<Events>();
  const seen: Array<{ id: string; size: number }> = [];
  e.on("saved", (p) => seen.push(p));
  assert.equal(e.emit("saved", { id: "a", size: 1 }), 1);
  assert.deepEqual(seen, [{ id: "a", size: 1 }]);
});

test("emit with no listeners returns 0", () => {
  const e = createEmitter<Events>();
  assert.equal(e.emit("tick", 7), 0);
  assert.equal(e.listenerCount("tick"), 0);
});

test("listeners run in registration order", () => {
  const e = createEmitter<Events>();
  const order: string[] = [];
  e.on("tick", () => order.push("first"));
  e.on("tick", () => order.push("second"));
  e.on("tick", () => order.push("third"));
  assert.equal(e.emit("tick", 1), 3);
  assert.deepEqual(order, ["first", "second", "third"]);
});

test("the same function registered twice is called twice", () => {
  const e = createEmitter<Events>();
  let n = 0;
  const bump = (): void => {
    n += 1;
  };
  e.on("tick", bump);
  e.on("tick", bump);
  assert.equal(e.listenerCount("tick"), 2);
  assert.equal(e.emit("tick", 1), 2);
  assert.equal(n, 2);
  e.off("tick", bump);
  assert.equal(e.listenerCount("tick"), 1);
  assert.equal(e.emit("tick", 1), 1);
  assert.equal(n, 3);
});

test("the unsubscribe function removes exactly one registration and is idempotent", () => {
  const e = createEmitter<Events>();
  let n = 0;
  const bump = (): void => {
    n += 1;
  };
  const off1 = e.on("tick", bump);
  e.on("tick", bump);
  off1();
  off1();
  assert.equal(e.listenerCount("tick"), 1);
  assert.equal(e.emit("tick", 1), 1);
  assert.equal(n, 1);
});

test("once fires a single time and is removed before it runs", () => {
  const e = createEmitter<Events>();
  let n = 0;
  e.once("tick", () => {
    n += 1;
    // re-entering must not find the listener any more
    e.emit("tick", 2);
  });
  assert.equal(e.emit("tick", 1), 1);
  assert.equal(n, 1);
  assert.equal(e.listenerCount("tick"), 0);
  assert.equal(e.emit("tick", 3), 0);
});

test("off removes a once registration by its original function", () => {
  const e = createEmitter<Events>();
  let n = 0;
  const bump = (): void => {
    n += 1;
  };
  e.once("tick", bump);
  assert.equal(e.listenerCount("tick"), 1);
  e.off("tick", bump);
  assert.equal(e.listenerCount("tick"), 0);
  assert.equal(e.emit("tick", 1), 0);
  assert.equal(n, 0);
});

test("off on an unregistered listener is a no-op", () => {
  const e = createEmitter<Events>();
  e.off("tick", () => {});
  e.on("tick", () => {});
  e.off("tick", () => {});
  assert.equal(e.listenerCount("tick"), 1);
});

test("a listener registered during an emit is not called by that emit", () => {
  const e = createEmitter<Events>();
  const order: string[] = [];
  e.on("tick", () => {
    order.push("outer");
    e.on("tick", () => order.push("inner"));
  });
  assert.equal(e.emit("tick", 1), 1);
  assert.deepEqual(order, ["outer"]);
  assert.equal(e.listenerCount("tick"), 2);
  assert.equal(e.emit("tick", 2), 2);
  assert.deepEqual(order, ["outer", "outer", "inner"]);
});

test("a listener removed during an emit is not called by that emit", () => {
  const e = createEmitter<Events>();
  const order: string[] = [];
  const second = (): void => {
    order.push("second");
  };
  e.on("tick", () => {
    order.push("first");
    e.off("tick", second);
  });
  e.on("tick", second);
  e.on("tick", () => order.push("third"));
  assert.equal(e.emit("tick", 1), 2);
  assert.deepEqual(order, ["first", "third"]);
});

test("events are independent", () => {
  const e = createEmitter<Events>();
  let ticks = 0;
  let closes = 0;
  e.on("tick", () => {
    ticks += 1;
  });
  e.on("closed", () => {
    closes += 1;
  });
  assert.equal(e.emit("tick", 1), 1);
  assert.equal(ticks, 1);
  assert.equal(closes, 0);
  assert.equal(e.listenerCount("closed"), 1);
  assert.equal(e.emit("closed", undefined), 1);
  assert.equal(closes, 1);
});

test("separate emitters keep separate registries", () => {
  const a = createEmitter<Events>();
  const b = createEmitter<Events>();
  let n = 0;
  a.on("tick", () => {
    n += 1;
  });
  assert.equal(b.listenerCount("tick"), 0);
  assert.equal(b.emit("tick", 1), 0);
  assert.equal(n, 0);
  assert.equal(a.emit("tick", 1), 1);
  assert.equal(n, 1);
});
