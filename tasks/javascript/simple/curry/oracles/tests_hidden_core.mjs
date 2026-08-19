import test from "node:test";
import assert from "node:assert/strict";
import { curry } from "./curry.mjs";

const add3 = (a, b, c) => a + b + c;

test("one argument at a time", () => {
  assert.equal(curry(add3)(1)(2)(3), 6);
});

test("any grouping of arguments works", () => {
  const c = curry(add3);
  assert.equal(c(1, 2)(3), 6);
  assert.equal(c(1)(2, 3), 6);
  assert.equal(c(1, 2, 3), 6);
});

test("intermediate results are functions", () => {
  const c = curry(add3);
  assert.equal(typeof c(1), "function");
  assert.equal(typeof c(1)(2), "function");
  assert.equal(typeof c(1)(2)(3), "number");
});

test("partials are reusable and independent", () => {
  const add = curry(add3);
  const from5 = add(5);
  assert.equal(from5(1, 1), 7);
  assert.equal(from5(10, 10), 25);
  const from5and1 = from5(1);
  assert.equal(from5and1(2), 8);
  assert.equal(from5and1(3), 9);
  assert.equal(from5(0, 0), 5);
});

test("arity defaults to fn.length", () => {
  const one = curry((a) => a * 2);
  assert.equal(one(21), 42);
  const four = curry((a, b, c, d) => `${a}${b}${c}${d}`);
  assert.equal(four("a")("b")("c")("d"), "abcd");
});

test("an explicit arity drives a variadic function", () => {
  const sum = curry((...xs) => xs.reduce((a, b) => a + b, 0), 3);
  assert.equal(sum(1)(2)(3), 6);
  assert.equal(sum(1, 2)(3), 6);
});

test("arguments beyond the arity are forwarded", () => {
  const collect = curry((a, b, ...rest) => [a, b, rest], 2);
  assert.deepEqual(collect(1, 2, 3, 4), [1, 2, [3, 4]]);
  assert.deepEqual(collect(1)(2, 3), [1, 2, [3]]);
  assert.deepEqual(collect(1)(2), [1, 2, []]);
});

test("the wrapped function runs exactly once per completed application", () => {
  let calls = 0;
  const c = curry((a, b) => {
    calls += 1;
    return a + b;
  });
  const p = c(1);
  assert.equal(p(2), 3);
  assert.equal(calls, 1);
  assert.equal(p(3), 4);
  assert.equal(calls, 2);
});

test("values of any type flow through", () => {
  const pack = curry((a, b, c) => ({ a, b, c }));
  const obj = { k: 1 };
  assert.deepEqual(pack(null)(undefined)(obj), { a: null, b: undefined, c: obj });
});

test("undefined counts as a supplied argument", () => {
  const c = curry((a, b) => [a, b]);
  assert.deepEqual(c(undefined)(2), [undefined, 2]);
});

test("a single-argument function still curries", () => {
  const id = curry((x) => x);
  assert.equal(id(9), 9);
});
