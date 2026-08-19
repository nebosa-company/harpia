// curry(fn, arity) with placeholder support.

export const _ = Symbol("curry.placeholder");

function remaining(collected, arity) {
  let holes = Math.max(0, arity - collected.length);
  for (let i = 0; i < Math.min(arity, collected.length); i++) {
    if (collected[i] === _) holes += 1;
  }
  return holes;
}

function make(fn, arity, collected) {
  const curried = function (...incoming) {
    const next = [];
    let j = 0;
    for (const held of collected) {
      if (held === _ && j < incoming.length) next.push(incoming[j++]);
      else next.push(held);
    }
    while (j < incoming.length) next.push(incoming[j++]);

    if (next.length >= arity && !next.includes(_)) {
      return fn.apply(this, next);
    }
    return make(fn, arity, next);
  };
  Object.defineProperty(curried, "length", {
    value: remaining(collected, arity),
    configurable: true,
  });
  return curried;
}

export function curry(fn, arity = typeof fn === "function" ? fn.length : 0) {
  if (typeof fn !== "function") {
    throw new TypeError("curry expects a function");
  }
  if (!Number.isInteger(arity) || arity < 0) {
    throw new TypeError("arity must be a non-negative integer");
  }
  return make(fn, arity, []);
}
