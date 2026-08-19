// range(start, end, step) -> lazy, re-iterable sequence with map/filter/take.

function lazy(makeIterator) {
  const seq = {
    [Symbol.iterator]: makeIterator,
    map(fn) {
      if (typeof fn !== "function") throw new TypeError("map expects a function");
      return lazy(function* () {
        let i = 0;
        for (const v of seq) yield fn(v, i++);
      });
    },
    filter(pred) {
      if (typeof pred !== "function") throw new TypeError("filter expects a function");
      return lazy(function* () {
        let i = 0;
        for (const v of seq) {
          if (pred(v, i++)) yield v;
        }
      });
    },
    take(n) {
      if (!Number.isInteger(n) || n < 0) {
        throw new TypeError("take expects a non-negative integer");
      }
      return lazy(function* () {
        if (n === 0) return;
        let taken = 0;
        for (const v of seq) {
          yield v;
          taken += 1;
          if (taken >= n) return;
        }
      });
    },
    toArray() {
      const out = [];
      for (const v of seq) out.push(v);
      return out;
    },
  };
  return seq;
}

export function range(start, end, step = 1) {
  for (const [name, v] of [["start", start], ["end", end], ["step", step]]) {
    if (typeof v !== "number" || !Number.isFinite(v)) {
      throw new TypeError(`${name} must be a finite number`);
    }
  }
  if (step === 0) throw new RangeError("step must not be 0");
  return lazy(function* () {
    if (step > 0) {
      for (let v = start; v < end; v += step) yield v;
    } else {
      for (let v = start; v > end; v += step) yield v;
    }
  });
}
