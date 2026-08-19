import test from "node:test";
import assert from "node:assert/strict";
import { parseQuery, formatQuery } from "./query.mjs";

test("parses simple pairs", () => {
  assert.deepEqual({ ...parseQuery("a=1&b=two") }, { a: "1", b: "two" });
});

test("ignores a leading question mark", () => {
  assert.deepEqual({ ...parseQuery("?a=1") }, { a: "1" });
});

test("splits on the first equals sign only", () => {
  assert.deepEqual({ ...parseQuery("eq=a=b=c") }, { eq: "a=b=c" });
});

test("key with no equals gets empty string value", () => {
  assert.deepEqual({ ...parseQuery("flag&x=1") }, { flag: "", x: "1" });
});

test("percent and plus decoding", () => {
  assert.deepEqual(
    { ...parseQuery("q=caf%C3%A9+au+lait&path=%2Fhome") },
    { q: "café au lait", path: "/home" },
  );
});

test("repeated keys collect into arrays in order", () => {
  assert.deepEqual(
    { ...parseQuery("tag=a&x=0&tag=b&tag=c") },
    { tag: ["a", "b", "c"], x: "0" },
  );
});

test("empty segments are skipped", () => {
  assert.deepEqual({ ...parseQuery("a=1&&b=2&") }, { a: "1", b: "2" });
});

test("formatQuery joins pairs and encodes", () => {
  assert.equal(formatQuery({ q: "a b", n: 3 }), "q=a+b&n=3");
  assert.equal(formatQuery({ "a&b": "x=y" }), "a%26b=x%3Dy");
});

test("formatQuery expands arrays in order", () => {
  assert.equal(formatQuery({ tag: ["a", "b"], x: 1 }), "tag=a&tag=b&x=1");
});
