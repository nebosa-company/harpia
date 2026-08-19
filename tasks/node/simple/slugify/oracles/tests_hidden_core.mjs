import test from "node:test";
import assert from "node:assert/strict";
import { slugify } from "./slugify.mjs";

test("lowercases and joins words", () => {
  assert.equal(slugify("Hello World"), "hello-world");
});

test("collapses punctuation and whitespace runs", () => {
  assert.equal(slugify("  Hello,   World!  "), "hello-world");
  assert.equal(slugify("foo_bar--baz"), "foo-bar-baz");
});

test("strips diacritics", () => {
  assert.equal(slugify("Crème Brûlée"), "creme-brulee");
  assert.equal(slugify("mañana señor"), "manana-senor");
  assert.equal(slugify("Über Café"), "uber-cafe");
});

test("keeps digits", () => {
  assert.equal(slugify("Node.js 24 release"), "node-js-24-release");
  assert.equal(slugify("100 Days"), "100-days");
});

test("no leading or trailing separators", () => {
  assert.equal(slugify("--already--slugged--"), "already-slugged");
  assert.equal(slugify("...dots..."), "dots");
});
