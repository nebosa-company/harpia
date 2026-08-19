// memoize(fn, options) -> WeakMap-backed memoizer with a TTL.

const defaultKeyFor = (...rest) => JSON.stringify(rest);

export function memoize(fn, options = {}) {
  if (typeof fn !== "function") {
    throw new TypeError("memoize expects a function");
  }
  const { ttl = Infinity, clock = Date.now, keyFor = defaultKeyFor } = options ?? {};
  if (typeof ttl !== "number" || Number.isNaN(ttl) || ttl < 0) {
    throw new TypeError("ttl must be a non-negative number");
  }
  if (typeof clock !== "function") throw new TypeError("clock must be a function");
  if (typeof keyFor !== "function") throw new TypeError("keyFor must be a function");

  let cache = new WeakMap();
  let hits = 0;
  let misses = 0;

  function memoized(subject, ...rest) {
    if (subject === null || (typeof subject !== "object" && typeof subject !== "function")) {
      throw new TypeError("the first argument must be an object");
    }
    let bucket = cache.get(subject);
    if (!bucket) {
      bucket = new Map();
      cache.set(subject, bucket);
    }
    const key = keyFor(...rest);
    const now = clock();
    const entry = bucket.get(key);
    if (entry !== undefined && now - entry.at < ttl) {
      hits += 1;
      return entry.value;
    }
    misses += 1;
    const value = fn.call(this, subject, ...rest);
    const stored = { value, at: now };
    bucket.set(key, stored);
    if (value !== null && typeof value === "object" && typeof value.then === "function") {
      value.then(undefined, () => {
        if (bucket.get(key) === stored) bucket.delete(key);
      });
    }
    return value;
  }

  memoized.invalidate = (subject) => {
    if (subject === null || (typeof subject !== "object" && typeof subject !== "function")) {
      return false;
    }
    return cache.delete(subject);
  };
  memoized.clear = () => {
    cache = new WeakMap();
  };
  memoized.stats = () => ({ hits, misses });
  Object.defineProperty(memoized, "cache", {
    get: () => cache,
    enumerable: true,
    configurable: true,
  });

  return memoized;
}
