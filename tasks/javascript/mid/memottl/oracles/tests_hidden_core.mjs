import test from "node:test";
import assert from "node:assert/strict";
import { memoize } from "./memo.mjs";

test("a repeated call is served from the cache", () => {
  let calls = 0;
  const memo = memoize((obj) => {
    calls += 1;
    return obj.n * 2;
  });
  const key = { n: 21 };
  assert.equal(memo(key), 42);
  assert.equal(memo(key), 42);
  assert.equal(memo(key), 42);
  assert.equal(calls, 1);
});

test("caching is by identity, not by shape", () => {
  let calls = 0;
  const memo = memoize((obj) => {
    calls += 1;
    return obj.n;
  });
  const a = { n: 1 };
  const b = { n: 1 };
  memo(a);
  memo(b);
  memo(a);
  assert.equal(calls, 2);
});

test("extra arguments select different entries", () => {
  let calls = 0;
  const memo = memoize((obj, suffix) => {
    calls += 1;
    return `${obj.name}-${suffix}`;
  });
  const key = { name: "x" };
  assert.equal(memo(key, "a"), "x-a");
  assert.equal(memo(key, "b"), "x-b");
  assert.equal(memo(key, "a"), "x-a");
  assert.equal(calls, 2);
});

test("entries expire once the ttl has passed", () => {
  let now = 0;
  let calls = 0;
  const memo = memoize(
    (obj) => {
      calls += 1;
      return calls;
    },
    { ttl: 100, clock: () => now },
  );
  const key = {};
  assert.equal(memo(key), 1);
  now = 99;
  assert.equal(memo(key), 1, "still fresh at ttl - 1");
  now = 100;
  assert.equal(memo(key), 2, "expired at exactly ttl");
  now = 150;
  assert.equal(memo(key), 2, "the fresh entry was stored at 100");
  now = 200;
  assert.equal(memo(key), 3);
  assert.equal(calls, 3);
});

test("without a ttl nothing expires", () => {
  let now = 0;
  let calls = 0;
  const memo = memoize(
    () => {
      calls += 1;
      return calls;
    },
    { clock: () => now },
  );
  const key = {};
  memo(key);
  now = 1e12;
  memo(key);
  assert.equal(calls, 1);
});

test("a ttl of 0 recomputes every time", () => {
  let calls = 0;
  const memo = memoize(
    () => {
      calls += 1;
      return calls;
    },
    { ttl: 0, clock: () => 5 },
  );
  const key = {};
  memo(key);
  memo(key);
  memo(key);
  assert.equal(calls, 3);
});

test("stats count hits and misses", () => {
  const memo = memoize((obj) => obj.n);
  const a = { n: 1 };
  const b = { n: 2 };
  assert.deepEqual(memo.stats(), { hits: 0, misses: 0 });
  memo(a);
  memo(a);
  memo(b);
  memo(a);
  assert.deepEqual(memo.stats(), { hits: 2, misses: 2 });
});

test("the cache is a WeakMap", () => {
  const memo = memoize((obj) => obj);
  assert.ok(memo.cache instanceof WeakMap);
  const key = {};
  memo(key);
  assert.equal(memo.cache.has(key), true);
  assert.equal(memo.cache.has({}), false);
});

test("a non-object first argument is a TypeError", () => {
  const memo = memoize((x) => x);
  for (const bad of [null, undefined, 1, "s", true, Symbol("s"), 10n]) {
    assert.throws(() => memo(bad), TypeError, String(bad));
  }
  assert.doesNotThrow(() => memo([]));
  assert.doesNotThrow(() => memo(() => {}));
});

test("invalidate drops one object's entries", () => {
  let calls = 0;
  const memo = memoize((obj, extra) => {
    calls += 1;
    return calls;
  });
  const a = {};
  const b = {};
  memo(a, 1);
  memo(a, 2);
  memo(b, 1);
  assert.equal(calls, 3);
  assert.equal(memo.invalidate(a), true);
  assert.equal(memo.invalidate(a), false);
  memo(a, 1);
  memo(a, 2);
  assert.equal(calls, 5);
  memo(b, 1);
  assert.equal(calls, 5, "b was untouched");
});

test("clear empties everything", () => {
  let calls = 0;
  const memo = memoize(() => {
    calls += 1;
    return calls;
  });
  const a = {};
  const b = {};
  memo(a);
  memo(b);
  assert.equal(calls, 2);
  memo.clear();
  memo(a);
  memo(b);
  assert.equal(calls, 4);
  assert.ok(memo.cache instanceof WeakMap);
});

test("memoize validates its arguments", () => {
  assert.throws(() => memoize(null), TypeError);
  assert.throws(() => memoize("fn"), TypeError);
  const fn = () => 1;
  assert.throws(() => memoize(fn, { ttl: -1 }), TypeError);
  assert.throws(() => memoize(fn, { ttl: NaN }), TypeError);
  assert.throws(() => memoize(fn, { ttl: "100" }), TypeError);
  assert.throws(() => memoize(fn, { clock: 5 }), TypeError);
  assert.throws(() => memoize(fn, { keyFor: "nope" }), TypeError);
  assert.doesNotThrow(() => memoize(fn, { ttl: Infinity }));
  assert.doesNotThrow(() => memoize(fn));
});
