import test from "node:test";
import assert from "node:assert/strict";
import { memoize } from "./memo.mjs";

const flush = () => new Promise((resolve) => setImmediate(resolve));

test("a thrown error is not cached", () => {
  let calls = 0;
  const memo = memoize(() => {
    calls += 1;
    throw new Error(`attempt ${calls}`);
  });
  const key = {};
  assert.throws(() => memo(key), /attempt 1/);
  assert.throws(() => memo(key), /attempt 2/);
  assert.equal(calls, 2);
});

test("a promise is cached so concurrent callers share it", async () => {
  let calls = 0;
  const memo = memoize(async (obj) => {
    calls += 1;
    return obj.n;
  });
  const key = { n: 7 };
  const first = memo(key);
  const second = memo(key);
  assert.equal(first, second, "the same promise is handed out");
  assert.equal(await first, 7);
  assert.equal(await second, 7);
  assert.equal(calls, 1);
});

test("a rejected promise is dropped so the next call retries", async () => {
  let calls = 0;
  const memo = memoize(async () => {
    calls += 1;
    throw new Error(`fail ${calls}`);
  });
  const key = {};
  await assert.rejects(memo(key), /fail 1/);
  await flush();
  await assert.rejects(memo(key), /fail 2/);
  assert.equal(calls, 2);
});

test("a rejected promise leaves no unhandled rejection behind", async () => {
  const seen = [];
  const onUnhandled = (reason) => seen.push(reason);
  process.on("unhandledRejection", onUnhandled);
  try {
    const memo = memoize(async () => {
      throw new Error("boom");
    });
    const key = {};
    await assert.rejects(memo(key), /boom/);
    await flush();
    await flush();
  } finally {
    process.off("unhandledRejection", onUnhandled);
  }
  assert.deepEqual(seen, []);
});

test("a fulfilled promise stays cached", async () => {
  let calls = 0;
  const memo = memoize(async () => {
    calls += 1;
    return calls;
  });
  const key = {};
  assert.equal(await memo(key), 1);
  await flush();
  assert.equal(await memo(key), 1);
  assert.equal(calls, 1);
});

test("this is forwarded to the wrapped function", () => {
  const memo = memoize(function (obj) {
    return this.base + obj.n;
  });
  const host = { base: 100, compute: memo };
  assert.equal(host.compute({ n: 5 }), 105);
});

test("every argument is forwarded", () => {
  const seen = [];
  const memo = memoize((obj, a, b) => {
    seen.push([obj, a, b]);
    return a + b;
  });
  const key = {};
  assert.equal(memo(key, 1, 2), 3);
  assert.deepEqual(seen, [[key, 1, 2]]);
});

test("the default sub-key distinguishes argument shapes", () => {
  let calls = 0;
  const memo = memoize((obj, arg) => {
    calls += 1;
    return calls;
  });
  const key = {};
  assert.equal(memo(key, { a: 1 }), 1);
  assert.equal(memo(key, { a: 1 }), 1, "structurally equal arguments share an entry");
  assert.equal(memo(key, { a: 2 }), 2);
  assert.equal(memo(key), 3);
  assert.equal(memo(key), 3);
  assert.equal(calls, 3);
});

test("a custom keyFor decides what shares an entry", () => {
  let calls = 0;
  const memo = memoize(
    (obj, name) => {
      calls += 1;
      return `${calls}:${name}`;
    },
    { keyFor: (name) => String(name).toLowerCase() },
  );
  const key = {};
  assert.equal(memo(key, "Alpha"), "1:Alpha");
  assert.equal(memo(key, "alpha"), "1:Alpha", "the key folds case");
  assert.equal(memo(key, "beta"), "2:beta");
  assert.equal(calls, 2);
});

test("keyFor receives only the arguments after the first", () => {
  const seen = [];
  const memo = memoize(
    () => 1,
    {
      keyFor: (...rest) => {
        seen.push(rest);
        return JSON.stringify(rest);
      },
    },
  );
  const key = { marker: true };
  memo(key, "a", 2);
  memo(key);
  assert.deepEqual(seen, [["a", 2], []]);
});

test("the clock is consulted on every call", () => {
  let reads = 0;
  const memo = memoize(() => 1, {
    ttl: 10,
    clock: () => {
      reads += 1;
      return 0;
    },
  });
  const key = {};
  memo(key);
  memo(key);
  memo(key);
  assert.ok(reads >= 3, `clock consulted ${reads} times`);
});

test("an expired entry counts as a miss", () => {
  let now = 0;
  const memo = memoize(() => 1, { ttl: 10, clock: () => now });
  const key = {};
  memo(key);
  memo(key);
  now = 50;
  memo(key);
  assert.deepEqual(memo.stats(), { hits: 1, misses: 2 });
});

test("functions and arrays work as cache keys", () => {
  let calls = 0;
  const memo = memoize(() => {
    calls += 1;
    return calls;
  });
  const fnKey = () => {};
  const arrKey = [1, 2];
  assert.equal(memo(fnKey), 1);
  assert.equal(memo(fnKey), 1);
  assert.equal(memo(arrKey), 2);
  assert.equal(memo(arrKey), 2);
  assert.equal(calls, 2);
});

test("invalidate ignores non-objects", () => {
  const memo = memoize((obj) => obj);
  assert.equal(memo.invalidate(42), false);
  assert.equal(memo.invalidate(null), false);
  assert.equal(memo.invalidate({}), false);
});

test("two memoized wrappers are independent", () => {
  let a = 0;
  let b = 0;
  const first = memoize(() => (a += 1));
  const second = memoize(() => (b += 1));
  const key = {};
  first(key);
  first(key);
  second(key);
  assert.equal(a, 1);
  assert.equal(b, 1);
  assert.notEqual(first.cache, second.cache);
  first.clear();
  second(key);
  assert.equal(b, 1);
});

test("stats are a snapshot, not a live object", () => {
  const memo = memoize(() => 1);
  const key = {};
  memo(key);
  const snapshot = memo.stats();
  memo(key);
  assert.deepEqual(snapshot, { hits: 0, misses: 1 });
  assert.deepEqual(memo.stats(), { hits: 1, misses: 1 });
});
