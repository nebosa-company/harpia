import test from "node:test";
import assert from "node:assert/strict";
import { signal, computed, effect, batch, untracked } from "./signals.mjs";

test("a signal holds and updates a value", () => {
  const s = signal(1);
  assert.equal(s.value, 1);
  s.value = 2;
  assert.equal(s.value, 2);
});

test("a computed derives from a signal", () => {
  const a = signal(2);
  const double = computed(() => a.value * 2);
  assert.equal(double.value, 4);
  a.value = 5;
  assert.equal(double.value, 10);
});

test("a computed is lazy and cached", () => {
  let runs = 0;
  const a = signal(1);
  const double = computed(() => {
    runs += 1;
    return a.value * 2;
  });
  assert.equal(runs, 0, "not evaluated before it is read");
  assert.equal(double.value, 2);
  assert.equal(double.value, 2);
  assert.equal(runs, 1, "cached while nothing changed");
  a.value = 3;
  assert.equal(runs, 1, "still not evaluated until read again");
  assert.equal(double.value, 6);
  assert.equal(runs, 2);
});

test("computeds chain", () => {
  const a = signal(1);
  const b = computed(() => a.value + 1);
  const c = computed(() => b.value * 10);
  assert.equal(c.value, 20);
  a.value = 4;
  assert.equal(c.value, 50);
});

test("an effect runs immediately and on every change", () => {
  const a = signal(1);
  const seen = [];
  effect(() => seen.push(a.value));
  assert.deepEqual(seen, [1]);
  a.value = 2;
  a.value = 3;
  assert.deepEqual(seen, [1, 2, 3]);
});

test("an effect sees computed values", () => {
  const a = signal(1);
  const double = computed(() => a.value * 2);
  const seen = [];
  effect(() => seen.push(double.value));
  a.value = 5;
  assert.deepEqual(seen, [2, 10]);
});

test("writing the same value wakes nobody", () => {
  const a = signal(1);
  let runs = 0;
  effect(() => {
    a.value;
    runs += 1;
  });
  assert.equal(runs, 1);
  a.value = 1;
  a.value = 1;
  assert.equal(runs, 1);
  a.value = 2;
  assert.equal(runs, 2);
});

test("NaN counts as unchanged", () => {
  const a = signal(NaN);
  let runs = 0;
  effect(() => {
    a.value;
    runs += 1;
  });
  a.value = NaN;
  assert.equal(runs, 1);
});

test("disposing stops an effect", () => {
  const a = signal(1);
  const seen = [];
  const dispose = effect(() => seen.push(a.value));
  a.value = 2;
  assert.equal(dispose(), true);
  a.value = 3;
  assert.equal(dispose(), false);
  assert.deepEqual(seen, [1, 2]);
});

test("the diamond runs its effect exactly once, with consistent values", () => {
  const a = signal(1);
  const b = computed(() => a.value + 1);
  const c = computed(() => a.value * 10);
  const seen = [];
  effect(() => seen.push(`${b.value}/${c.value}`));
  assert.deepEqual(seen, ["2/10"]);
  a.value = 2;
  assert.deepEqual(seen, ["2/10", "3/20"]);
  a.value = 3;
  assert.deepEqual(seen, ["2/10", "3/20", "4/30"]);
});

test("a deeper diamond still runs once", () => {
  const a = signal(1);
  const b = computed(() => a.value + 1);
  const c = computed(() => b.value + 1);
  const d = computed(() => a.value + 100);
  let runs = 0;
  const seen = [];
  effect(() => {
    runs += 1;
    seen.push([c.value, d.value]);
  });
  a.value = 2;
  assert.equal(runs, 2);
  assert.deepEqual(seen, [
    [3, 101],
    [4, 102],
  ]);
});

test("batch coalesces writes into one effect run", () => {
  const a = signal(1);
  const b = signal(2);
  const seen = [];
  effect(() => seen.push(a.value + b.value));
  assert.deepEqual(seen, [3]);
  const result = batch(() => {
    a.value = 10;
    b.value = 20;
    return "returned";
  });
  assert.equal(result, "returned");
  assert.deepEqual(seen, [3, 30]);
});

test("several effects on one signal all run, in creation order", () => {
  const a = signal(0);
  const order = [];
  effect(() => {
    a.value;
    order.push("first");
  });
  effect(() => {
    a.value;
    order.push("second");
  });
  effect(() => {
    a.value;
    order.push("third");
  });
  order.length = 0;
  a.value = 1;
  assert.deepEqual(order, ["first", "second", "third"]);
});

test("an effect that reads two signals runs once per write", () => {
  const a = signal(1);
  const b = signal(1);
  let runs = 0;
  effect(() => {
    a.value;
    b.value;
    runs += 1;
  });
  a.value = 2;
  b.value = 2;
  assert.equal(runs, 3);
});

test("a computed nobody reads costs nothing", () => {
  let runs = 0;
  const a = signal(1);
  computed(() => {
    runs += 1;
    return a.value;
  });
  a.value = 2;
  a.value = 3;
  assert.equal(runs, 0);
});

test("independent graphs do not interfere", () => {
  const a = signal(1);
  const b = signal(1);
  const seenA = [];
  const seenB = [];
  effect(() => seenA.push(a.value));
  effect(() => seenB.push(b.value));
  a.value = 2;
  assert.deepEqual(seenA, [1, 2]);
  assert.deepEqual(seenB, [1]);
});
