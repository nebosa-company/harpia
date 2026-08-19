import test from "node:test";
import assert from "node:assert/strict";
import { render } from "./template.mjs";

test("substitutes simple placeholders", () => {
  assert.equal(render("Hi {{name}}!", { name: "Ada" }), "Hi Ada!");
});

test("whitespace inside braces is tolerated", () => {
  assert.equal(render("Hi {{  name  }}!", { name: "Ada" }), "Hi Ada!");
});

test("dotted paths traverse nested objects", () => {
  const data = { user: { profile: { name: "Grace" } } };
  assert.equal(render("{{user.profile.name}}", data), "Grace");
});

test("array indices work as segments", () => {
  assert.equal(render("{{items.1}}", { items: ["a", "b", "c"] }), "b");
  assert.equal(
    render("{{list.0.id}}", { list: [{ id: 7 }] }),
    "7",
  );
});

test("multiple placeholders and surrounding text", () => {
  assert.equal(
    render("{{a}} + {{b}} = {{c}}", { a: 1, b: 2, c: 3 }),
    "1 + 2 = 3",
  );
});

test("numbers and booleans stringify", () => {
  assert.equal(render("{{n}}/{{f}}", { n: 0, f: false }), "0/false");
});

test("missing paths render empty by default", () => {
  assert.equal(render("[{{ nope.deep }}]", {}), "[]");
  assert.equal(render("[{{gone}}]", { gone: null }), "[]");
});
