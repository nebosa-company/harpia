import test from "node:test";
import assert from "node:assert/strict";
import { parseQuery, formatQuery } from "./query.mjs";

test("returned object has a null prototype", () => {
  const r = parseQuery("a=1");
  assert.equal(Object.getPrototypeOf(r), null);
});

test("__proto__ is stored as a plain own property", () => {
  const r = parseQuery("__proto__=polluted&constructor=x");
  assert.equal(r["__proto__"], "polluted");
  assert.equal(r["constructor"], "x");
  assert.equal({}.polluted, undefined);
});

test("empty inputs parse to empty objects", () => {
  assert.deepEqual({ ...parseQuery("") }, {});
  assert.deepEqual({ ...parseQuery("?") }, {});
});

test("invalid percent escapes are kept as-is, never thrown", () => {
  assert.deepEqual({ ...parseQuery("bad=%E0%A4%A") }, { bad: "%E0%A4%A" });
  assert.deepEqual({ ...parseQuery("%ZZkey=v") }, { "%ZZkey": "v" });
});

test("plus converts to space even when escape is invalid", () => {
  assert.deepEqual({ ...parseQuery("bad=a+b%GG") }, { bad: "a b%GG" });
});

test("non-string input throws TypeError", () => {
  assert.throws(() => parseQuery(null), TypeError);
  assert.throws(() => parseQuery(42), TypeError);
});

test("round-trip parse(format(params))", () => {
  const params = { q: "café au lait", tags: ["x y", "z&w"], page: 2 };
  const parsed = parseQuery(formatQuery(params));
  assert.deepEqual(
    { ...parsed },
    { q: "café au lait", tags: ["x y", "z&w"], page: "2" },
  );
});

test("decoded keys can repeat too", () => {
  assert.deepEqual({ ...parseQuery("k+1=a&k%201=b") }, { "k 1": ["a", "b"] });
});
