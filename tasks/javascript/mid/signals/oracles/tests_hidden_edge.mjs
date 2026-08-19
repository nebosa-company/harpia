import test from "node:test";
import assert from "node:assert/strict";
import { signal, computed, effect, batch, untracked } from "./signals.mjs";

test("dependencies are re-collected on every run", () => {
  const toggle = signal(true);
  const x = signal("x1");
  const y = signal("y1");
  const seen = [];
  effect(() => seen.push(toggle.value ? x.value : y.value));
  assert.deepEqual(seen, ["x1"]);
  y.value = "y2";
  assert.deepEqual(seen, ["x1"], "y is not a dependency yet");
  x.value = "x2";
  assert.deepEqual(seen, ["x1", "x2"]);
  toggle.value = false;
  assert.deepEqual(seen, ["x1", "x2", "y2"]);
  x.value = "x3";
  assert.deepEqual(seen, ["x1", "x2", "y2"], "x is no longer a dependency");
  y.value = "y3";
  assert.deepEqual(seen, ["x1", "x2", "y2", "y3"]);
});

test("a computed drops dependencies it stopped reading", () => {
  const toggle = signal(true);
  const x = signal(1);
  const y = signal(100);
  let runs = 0;
  const pick = computed(() => {
    runs += 1;
    return toggle.value ? x.value : y.value;
  });
  assert.equal(pick.value, 1);
  y.value = 200;
  assert.equal(pick.value, 1);
  assert.equal(runs, 1, "y was never a dependency");
  toggle.value = false;
  assert.equal(pick.value, 200);
  assert.equal(runs, 2);
  x.value = 7;
  assert.equal(pick.value, 200);
  assert.equal(runs, 2, "x is no longer a dependency");
});

test("untracked reads do not create dependencies", () => {
  const a = signal(1);
  const b = signal(2);
  const seen = [];
  effect(() => {
    seen.push(a.value + untracked(() => b.value));
  });
  assert.deepEqual(seen, [3]);
  b.value = 20;
  assert.deepEqual(seen, [3]);
  a.value = 10;
  assert.deepEqual(seen, [3, 30]);
});

test("untracked returns its callback's result", () => {
  const a = signal(5);
  assert.equal(
    untracked(() => a.value * 2),
    10,
  );
});

test("assigning to a computed is a TypeError", () => {
  const a = signal(1);
  const c = computed(() => a.value);
  assert.throws(() => {
    c.value = 5;
  }, TypeError);
  assert.equal(c.value, 1);
});

test("a self-referential computed reports a cycle", () => {
  const a = signal(1);
  let c;
  c = computed(() => a.value + c.value);
  assert.throws(() => c.value, /cycle/i);
});

test("a mutual computed cycle is reported", () => {
  let left;
  let right;
  left = computed(() => right.value + 1);
  right = computed(() => left.value + 1);
  assert.throws(() => left.value, /cycle/i);
});

test("nested batches release only at the outermost level", () => {
  const a = signal(1);
  const seen = [];
  effect(() => seen.push(a.value));
  batch(() => {
    a.value = 2;
    batch(() => {
      a.value = 3;
    });
    assert.deepEqual(seen, [1], "nothing runs inside the batch");
    a.value = 4;
  });
  assert.deepEqual(seen, [1, 4]);
});

test("a batch that throws still releases its effects", () => {
  const a = signal(1);
  const seen = [];
  effect(() => seen.push(a.value));
  assert.throws(() => {
    batch(() => {
      a.value = 2;
      throw new Error("batch failed");
    });
  }, /batch failed/);
  assert.deepEqual(seen, [1, 2]);
});

test("reads inside a batch see the new values immediately", () => {
  const a = signal(1);
  const double = computed(() => a.value * 2);
  batch(() => {
    a.value = 5;
    assert.equal(a.value, 5);
    assert.equal(double.value, 10);
  });
});

test("an effect may write another signal", () => {
  const a = signal(0);
  const b = signal(0);
  const log = [];
  effect(() => {
    b.value = a.value * 2;
  });
  effect(() => log.push(b.value));
  assert.deepEqual(log, [0]);
  a.value = 5;
  assert.deepEqual(log, [0, 10]);
  assert.equal(b.value, 10);
});

test("disposing inside a batch prevents the run", () => {
  const a = signal(1);
  const seen = [];
  const dispose = effect(() => seen.push(a.value));
  batch(() => {
    a.value = 2;
    dispose();
  });
  assert.deepEqual(seen, [1]);
});

test("a computed shared by two effects is evaluated once per change", () => {
  const a = signal(1);
  let runs = 0;
  const derived = computed(() => {
    runs += 1;
    return a.value * 2;
  });
  const seen = [];
  effect(() => seen.push(`x${derived.value}`));
  effect(() => seen.push(`y${derived.value}`));
  assert.equal(runs, 1);
  a.value = 2;
  assert.deepEqual(seen, ["x2", "y2", "x4", "y4"]);
  assert.equal(runs, 2);
});

test("an effect that reads nothing never re-runs", () => {
  const a = signal(1);
  let runs = 0;
  effect(() => {
    runs += 1;
  });
  a.value = 2;
  assert.equal(runs, 1);
});

test("a computed that throws propagates and stays re-evaluable", () => {
  const a = signal(0);
  const risky = computed(() => {
    if (a.value === 0) throw new Error("no zero");
    return 10 / a.value;
  });
  assert.throws(() => risky.value, /no zero/);
  a.value = 2;
  assert.equal(risky.value, 5);
});

test("the primitives validate their arguments", () => {
  for (const bad of [null, undefined, 1, "fn", {}]) {
    assert.throws(() => computed(bad), TypeError, String(bad));
    assert.throws(() => effect(bad), TypeError, String(bad));
    assert.throws(() => batch(bad), TypeError, String(bad));
    assert.throws(() => untracked(bad), TypeError, String(bad));
  }
});

test("signals hold any value, objects included", () => {
  const first = { n: 1 };
  const second = { n: 1 };
  const s = signal(first);
  let runs = 0;
  effect(() => {
    s.value;
    runs += 1;
  });
  s.value = first;
  assert.equal(runs, 1, "same reference, no change");
  s.value = second;
  assert.equal(runs, 2, "different reference, change");
  assert.equal(s.value, second);
});
