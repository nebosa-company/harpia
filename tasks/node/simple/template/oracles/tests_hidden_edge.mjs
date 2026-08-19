import test from "node:test";
import assert from "node:assert/strict";
import { render } from "./template.mjs";

test("escaped braces emit literal {{", () => {
  assert.equal(render("\\{{x}}", { x: "no" }), "{{x}}");
  assert.equal(
    render("\\{{keep}} and {{use}}", { use: "this" }),
    "{{keep}} and this",
  );
});

test("other backslashes are literal", () => {
  assert.equal(render("C:\\temp\\dir {{f}}", { f: "a.txt" }), "C:\\temp\\dir a.txt");
  assert.equal(render("a\\b", {}), "a\\b");
});

test("backslash right before braces escapes them", () => {
  assert.equal(render("C:\\temp\\{{f}}", { f: "a.txt" }), "C:\\temp{{f}}");
});

test("stray closing braces are literal text", () => {
  assert.equal(render("a }} b", {}), "a }} b");
});

test("onMissing keep emits the original placeholder text", () => {
  assert.equal(
    render("x {{ user.age }} y", {}, { onMissing: "keep" }),
    "x {{ user.age }} y",
  );
});

test("onMissing error throws with the dotted path", () => {
  assert.throws(
    () => render("{{a.b.c}}", {}, { onMissing: "error" }),
    (err) => err instanceof Error && err.message.includes("a.b.c"),
  );
});

test("unclosed placeholder throws", () => {
  assert.throws(() => render("hello {{name", {}), /unclosed placeholder/);
});

test("invalid placeholder contents throw", () => {
  assert.throws(() => render("{{a b}}", { a: 1 }), /invalid placeholder/);
  assert.throws(() => render("{{}}", {}), /invalid placeholder/);
  assert.throws(() => render("{{a..b}}", {}), /invalid placeholder/);
});

test("objects and arrays render as JSON", () => {
  assert.equal(render("{{cfg}}", { cfg: { a: 1 } }), '{"a":1}');
  assert.equal(render("{{xs}}", { xs: [1, "two"] }), '[1,"two"]');
});

test("non-string template throws TypeError", () => {
  assert.throws(() => render(42, {}), TypeError);
});

test("traversing through a scalar counts as missing", () => {
  assert.equal(render("[{{a.b}}]", { a: "scalar" }), "[]");
});
