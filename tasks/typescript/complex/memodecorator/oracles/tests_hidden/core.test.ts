import { test } from "node:test";
import assert from "node:assert/strict";
import {
  cached,
  cachedWith,
  clearMethodCache,
  memoize,
  methodCacheSize,
} from "../src/cache";

test("a wrapped function is called once per distinct argument list", () => {
  let calls = 0;
  const add = memoize((a: number, b: number): number => {
    calls += 1;
    return a + b;
  });
  assert.equal(add(1, 2), 3);
  assert.equal(add(1, 2), 3);
  assert.equal(calls, 1);
  assert.equal(add(2, 1), 3);
  assert.equal(calls, 2);
  assert.equal(add.size, 2);
});

test("an undefined result is a hit, not a miss", () => {
  let calls = 0;
  const nothing = memoize((): undefined => {
    calls += 1;
    return undefined;
  });
  assert.equal(nothing(), undefined);
  assert.equal(nothing(), undefined);
  assert.equal(calls, 1);
  assert.equal(nothing.size, 1);
});

test("a throw is not cached and propagates", () => {
  let calls = 0;
  const boom = memoize((n: number): number => {
    calls += 1;
    if (n < 0) throw new RangeError("negative");
    return n;
  });
  assert.throws(() => boom(-1), RangeError);
  assert.throws(() => boom(-1), RangeError);
  assert.equal(calls, 2);
  assert.equal(boom.size, 0);
  assert.equal(boom.has(-1), false);
});

test("has, size and clear", () => {
  const twice = memoize((n: number): number => n * 2);
  assert.equal(twice.size, 0);
  assert.equal(twice.has(2), false);
  twice(2);
  assert.equal(twice.has(2), true);
  assert.equal(twice.size, 1);
  twice.clear();
  assert.equal(twice.size, 0);
  assert.equal(twice.has(2), false);
});

test("the wrapper forwards this", () => {
  const holder = {
    base: 10,
    plus: memoize(function (this: { base: number }, n: number): number {
      return this.base + n;
    }),
  };
  assert.equal(holder.plus(5), 15);
});

test("a custom key collapses arguments", () => {
  let calls = 0;
  const byFirst = memoize(
    (a: number, b: number): number => {
      calls += 1;
      return a + b;
    },
    { keyOf: (a) => String(a) },
  );
  assert.equal(byFirst(1, 2), 3);
  assert.equal(byFirst(1, 99), 3, "the second argument is not part of the key");
  assert.equal(calls, 1);
  assert.equal(byFirst.has(1, 0), true);
});

test("maxSize evicts the least recently used entry", () => {
  let calls = 0;
  const f = memoize(
    (n: number): number => {
      calls += 1;
      return n;
    },
    { maxSize: 2 },
  );
  f(1);
  f(2);
  assert.equal(f.size, 2);
  f(1);
  assert.equal(calls, 2, "1 was a hit");
  f(3);
  assert.equal(f.size, 2);
  assert.equal(f.has(1), true);
  assert.equal(f.has(2), false, "2 was the least recently used");
  assert.equal(f.has(3), true);
});

test("has does not count as a use", () => {
  const f = memoize((n: number): number => n, { maxSize: 2 });
  f(1);
  f(2);
  f.has(1);
  f(3);
  assert.equal(f.has(1), false, "reading with has must not refresh an entry");
  assert.equal(f.has(2), true);
  assert.equal(f.has(3), true);
});

test("an unusable maxSize is refused at wrap time", () => {
  const badSize = (err: unknown): boolean =>
    err instanceof RangeError && err.message === "maxSize must be a positive integer";
  assert.throws(() => memoize((n: number): number => n, { maxSize: 0 }), badSize);
  assert.throws(() => memoize((n: number): number => n, { maxSize: -1 }), badSize);
  assert.throws(() => memoize((n: number): number => n, { maxSize: 1.5 }), badSize);
  assert.throws(() => cachedWith({ maxSize: 0 }), badSize);
});

class Calc {
  calls = 0;
  offset = 100;

  @cached
  square(n: number): number {
    this.calls += 1;
    return n * n + this.offset;
  }

  @cached
  cube(n: number): number {
    this.calls += 1;
    return n * n * n;
  }

  @cachedWith({ maxSize: 2 })
  small(n: number): number {
    this.calls += 1;
    return n;
  }

  @cachedWith({ keyOf: (args) => String(args.length) })
  byArity(...ns: number[]): number {
    this.calls += 1;
    return ns.length;
  }
}

test("a decorated method caches and still sees its own this", () => {
  const c = new Calc();
  assert.equal(c.square(3), 109);
  assert.equal(c.square(3), 109);
  assert.equal(c.calls, 1);
  c.offset = 0;
  assert.equal(c.square(3), 109, "the cached value is returned, not recomputed");
  assert.equal(c.square(4), 16);
  assert.equal(c.calls, 2);
});

test("two instances do not share a cache", () => {
  const a = new Calc();
  const b = new Calc();
  a.square(2);
  assert.equal(a.calls, 1);
  assert.equal(b.calls, 0);
  b.square(2);
  assert.equal(b.calls, 1);
  assert.equal(methodCacheSize(a, "square"), 1);
  assert.equal(methodCacheSize(b, "square"), 1);
});

test("two decorated methods on one instance do not collide", () => {
  const c = new Calc();
  assert.equal(c.square(2), 104);
  assert.equal(c.cube(2), 8);
  assert.equal(c.calls, 2);
  assert.equal(c.square(2), 104);
  assert.equal(c.cube(2), 8);
  assert.equal(c.calls, 2);
  assert.equal(methodCacheSize(c, "square"), 1);
  assert.equal(methodCacheSize(c, "cube"), 1);
});

test("cachedWith honours maxSize per instance", () => {
  const c = new Calc();
  c.small(1);
  c.small(2);
  c.small(3);
  assert.equal(methodCacheSize(c, "small"), 2);
  assert.equal(c.calls, 3);
  c.small(3);
  assert.equal(c.calls, 3);
  c.small(1);
  assert.equal(c.calls, 4, "1 was evicted");
});

test("cachedWith honours a custom key over the argument array", () => {
  const c = new Calc();
  assert.equal(c.byArity(1, 2), 2);
  assert.equal(c.byArity(7, 8), 2, "same arity, same key");
  assert.equal(c.calls, 1);
  assert.equal(c.byArity(1), 1);
  assert.equal(c.calls, 2);
});

test("the cache helpers are safe on anything", () => {
  const c = new Calc();
  assert.equal(methodCacheSize(c, "square"), 0);
  assert.equal(methodCacheSize({}, "square"), 0);
  assert.equal(methodCacheSize(c, "nosuch"), 0);
  clearMethodCache(c, "square");
  clearMethodCache({}, "nosuch");
  c.square(2);
  assert.equal(methodCacheSize(c, "square"), 1);
  clearMethodCache(c, "square");
  assert.equal(methodCacheSize(c, "square"), 0);
  assert.equal(c.square(2), 104);
  assert.equal(c.calls, 2, "clearing forces a recompute");
});
