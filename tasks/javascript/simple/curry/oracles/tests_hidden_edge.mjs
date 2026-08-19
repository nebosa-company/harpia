import test from "node:test";
import assert from "node:assert/strict";
import { curry, _ } from "./curry.mjs";

const sub = (a, b) => a - b;
const three = (a, b, c) => `${a}-${b}-${c}`;

test("the placeholder is a symbol", () => {
  assert.equal(typeof _, "symbol");
});

test("a placeholder reserves a position", () => {
  assert.equal(curry(sub)(_, 5)(10), 5);
  assert.equal(curry(sub)(10, _)(5), 5);
});

test("several placeholders fill in order", () => {
  const c = curry(three);
  assert.equal(c(_, _, "c")("a")("b"), "a-b-c");
  assert.equal(c(_, "b", _)("a", "c"), "a-b-c");
  assert.equal(c("a", _, _)("b")("c"), "a-b-c");
});

test("a later call may reserve positions too", () => {
  const c = curry(three);
  assert.equal(c("a")(_, "c")("b"), "a-b-c");
});

test("placeholder partials are independent", () => {
  const flip = curry(sub)(_, 5);
  assert.equal(flip(10), 5);
  assert.equal(flip(20), 15);
});

test("length reports the positions still needed", () => {
  const c = curry(three);
  assert.equal(c.length, 3);
  assert.equal(c(1).length, 2);
  assert.equal(c(1, 2).length, 1);
  assert.equal(c(_, 2).length, 2);
  assert.equal(c(_, _, 3).length, 2);
  assert.equal(c(_, 2)(1).length, 1);
});

test("an explicit arity drives length", () => {
  const c = curry((...xs) => xs, 2);
  assert.equal(c.length, 2);
  assert.equal(c(1).length, 1);
});

test("calling with no arguments makes no progress", () => {
  const c = curry(three);
  const p = c(1);
  const q = p();
  assert.equal(typeof q, "function");
  assert.equal(q.length, 2);
  assert.equal(q(2)(3), "1-2-3");
  assert.equal(p(2, 3), "1-2-3");
});

test("this is forwarded from the completing call", () => {
  const method = curry(function (a, b) {
    return this.base + a + b;
  }, 2);
  const obj = { base: 100, method };
  assert.equal(obj.method(1, 2), 103);
  const partial = method(1);
  assert.equal(partial.call({ base: 5 }, 2), 8);
});

test("arity 0 calls straight through", () => {
  let calls = 0;
  const c = curry(() => {
    calls += 1;
    return "done";
  }, 0);
  assert.equal(c.length, 0);
  assert.equal(c(), "done");
  assert.equal(c(), "done");
  assert.equal(calls, 2);
});

test("bad arguments are TypeErrors", () => {
  assert.throws(() => curry(null), TypeError);
  assert.throws(() => curry("fn"), TypeError);
  assert.throws(() => curry({}), TypeError);
  assert.throws(() => curry(sub, -1), TypeError);
  assert.throws(() => curry(sub, 1.5), TypeError);
  assert.throws(() => curry(sub, "2"), TypeError);
});

test("the placeholder is never handed to the wrapped function", () => {
  const seen = [];
  const c = curry((a, b) => {
    seen.push(a, b);
    return a + b;
  });
  assert.equal(c(_, 2)(1), 3);
  assert.deepEqual(seen, [1, 2]);
  assert.equal(seen.includes(_), false);
});

test("a deeply partial application still completes", () => {
  const five = curry((a, b, c, d, e) => a + b + c + d + e);
  assert.equal(five(1)(_, 3)(2)(4)(5), 15);
});
