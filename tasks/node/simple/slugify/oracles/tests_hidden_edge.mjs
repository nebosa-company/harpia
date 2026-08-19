import test from "node:test";
import assert from "node:assert/strict";
import { slugify } from "./slugify.mjs";

test("ampersand becomes the word and", () => {
  assert.equal(slugify("Rock & Roll"), "rock-and-roll");
  assert.equal(slugify("AT&T stock"), "at-and-t-stock");
});

test("custom separator", () => {
  assert.equal(slugify("Hello World", { separator: "_" }), "hello_world");
  assert.equal(slugify("a b c", { separator: "" }), "abc");
  assert.equal(slugify("x y", { separator: "--" }), "x--y");
});

test("maxLength truncates and strips trailing separators", () => {
  assert.equal(slugify("hello world friends", { maxLength: 12 }), "hello-world");
  assert.equal(slugify("hello world friends", { maxLength: 11 }), "hello-world");
  assert.equal(slugify("hello world friends", { maxLength: 500 }), "hello-world-friends");
});

test("non-string input throws TypeError", () => {
  assert.throws(() => slugify(42), TypeError);
  assert.throws(() => slugify(null), TypeError);
  assert.throws(() => slugify(["a"]), TypeError);
});

test("empty and symbol-only inputs give empty slug", () => {
  assert.equal(slugify(""), "");
  assert.equal(slugify("!!! ***"), "");
});
