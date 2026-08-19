import test from "node:test";
import assert from "node:assert/strict";
import { h, render, diff, patch, toHtml } from "./vdom.mjs";

const names = (children) => children.map((c) => (typeof c === "string" ? c : c.type));

test("h builds a vnode", () => {
  const node = h("div", { id: "root" }, "hello");
  assert.equal(node.type, "div");
  assert.deepEqual(node.props, { id: "root" });
  assert.deepEqual(node.children, ["hello"]);
  assert.equal(node.key, null);
});

test("h defaults props and children", () => {
  const node = h("br");
  assert.deepEqual(node.props, {});
  assert.deepEqual(node.children, []);
  assert.deepEqual(h("p", null).props, {});
  assert.deepEqual(h("p", undefined).props, {});
});

test("h lifts the key out of props", () => {
  const node = h("li", { key: "a", id: "x" });
  assert.equal(node.key, "a");
  assert.deepEqual(node.props, { id: "x" });
  assert.equal(h("li", { key: 3 }).key, 3);
});

test("h flattens and normalizes children", () => {
  const node = h(
    "ul",
    null,
    "text",
    42,
    [h("li", null), [h("li", null), null]],
    undefined,
    false,
    true,
  );
  assert.deepEqual(names(node.children), ["text", "42", "li", "li"]);
  assert.equal(node.children[1], "42");
});

test("h validates its input", () => {
  assert.throws(() => h(""), TypeError);
  assert.throws(() => h(null), TypeError);
  assert.throws(() => h(42), TypeError);
  assert.throws(() => h("li", { key: {} }), TypeError);
  assert.throws(() => h("ul", null, h("li", { key: "a" }), h("li", { key: "a" })), Error);
  assert.throws(() => h("ul", null, h("li", { key: "a" }), h("li", null)), Error);
});

test("render produces host nodes", () => {
  const host = render(h("div", { id: "root", class: "box" }, h("span", null, "hi")));
  assert.deepEqual(host, {
    tag: "div",
    attrs: { id: "root", class: "box" },
    children: [{ tag: "span", attrs: {}, children: ["hi"] }],
  });
});

test("render drops null, undefined and false props", () => {
  const host = render(h("input", { type: "text", disabled: false, value: null, extra: undefined, checked: true }));
  assert.deepEqual(host.attrs, { type: "text", checked: true });
});

test("toHtml serializes a tree", () => {
  const host = render(h("div", { id: "a" }, h("span", null, "one"), "two"));
  assert.equal(toHtml(host), '<div id="a"><span>one</span>two</div>');
});

test("toHtml renders true as an empty value and escapes text", () => {
  assert.equal(toHtml(render(h("input", { checked: true, size: 4 }))), '<input checked="" size="4"></input>');
  assert.equal(toHtml(render(h("p", null, "a < b & c > d"))), "<p>a &lt; b &amp; c &gt; d</p>");
});

test("diffing a tree with itself yields nothing", () => {
  const tree = h("div", { id: "a" }, h("span", { class: "c" }, "text"), h("b", null, "bold"));
  assert.deepEqual(diff(tree, tree), []);
  const same = h("div", { id: "a" }, h("span", { class: "c" }, "text"), h("b", null, "bold"));
  assert.deepEqual(diff(tree, same), []);
});

test("a changed prop produces one props operation", () => {
  const before = h("div", { id: "a", class: "old" });
  const after = h("div", { id: "a", class: "new" });
  const ops = diff(before, after);
  assert.equal(ops.length, 1);
  assert.equal(ops[0].op, "props");
  assert.deepEqual(ops[0].path, []);
  assert.deepEqual(ops[0].set, { class: "new" });
  assert.deepEqual(ops[0].remove, []);
  const host = patch(render(before), ops);
  assert.equal(toHtml(host), toHtml(render(after)));
});

test("a removed prop is listed for removal", () => {
  const before = h("div", { id: "a", title: "t" });
  const after = h("div", { id: "a" });
  const ops = diff(before, after);
  assert.equal(ops.length, 1);
  assert.deepEqual(ops[0].remove, ["title"]);
  const host = patch(render(before), ops);
  assert.deepEqual(host.attrs, { id: "a" });
});

test("changed text produces a text operation", () => {
  const before = h("p", null, "old");
  const after = h("p", null, "new");
  const ops = diff(before, after);
  assert.equal(ops.length, 1);
  assert.equal(ops[0].op, "text");
  assert.deepEqual(ops[0].path, [0]);
  assert.equal(ops[0].value, "new");
  assert.equal(toHtml(patch(render(before), ops)), "<p>new</p>");
});

test("a different type is replaced", () => {
  const before = h("div", null, h("span", null, "x"));
  const after = h("div", null, h("b", null, "x"));
  const ops = diff(before, after);
  assert.equal(ops.length, 1);
  assert.equal(ops[0].op, "replace");
  assert.deepEqual(ops[0].path, [0]);
  assert.equal(toHtml(patch(render(before), ops)), "<div><b>x</b></div>");
});

test("replacing the root returns the new tree", () => {
  const before = h("div", null, "x");
  const after = h("section", null, "x");
  const ops = diff(before, after);
  assert.equal(ops[0].op, "replace");
  assert.deepEqual(ops[0].path, []);
  const host = render(before);
  const result = patch(host, ops);
  assert.equal(toHtml(result), "<section>x</section>");
});

test("appended and removed children", () => {
  const one = h("ul", null, h("li", null, "a"));
  const three = h("ul", null, h("li", null, "a"), h("li", null, "b"), h("li", null, "c"));
  const grown = patch(render(one), diff(one, three));
  assert.equal(toHtml(grown), "<ul><li>a</li><li>b</li><li>c</li></ul>");
  const shrunk = patch(render(three), diff(three, one));
  assert.equal(toHtml(shrunk), "<ul><li>a</li></ul>");
});

test("nested changes carry the right path", () => {
  const before = h("div", null, h("section", null, h("p", { class: "old" }, "text")));
  const after = h("div", null, h("section", null, h("p", { class: "new" }, "changed")));
  const ops = diff(before, after);
  assert.deepEqual(
    ops.map((o) => [o.op, o.path.join(".")]).sort(),
    [
      ["props", "0.0"],
      ["text", "0.0.0"],
    ].sort(),
  );
  assert.equal(toHtml(patch(render(before), ops)), toHtml(render(after)));
});

test("patch mutates in place and returns the same root", () => {
  const before = h("div", { id: "a" }, h("span", null, "x"));
  const after = h("div", { id: "b" }, h("span", null, "y"));
  const host = render(before);
  const span = host.children[0];
  const result = patch(host, diff(before, after));
  assert.equal(result, host);
  assert.equal(span.children[0], "y", "the untouched node object was updated in place");
  assert.equal(toHtml(result), '<div id="b"><span>y</span></div>');
});

test("a realistic update round-trips", () => {
  const before = h(
    "div",
    { id: "app" },
    h("h1", null, "Title"),
    h("ul", { class: "list" }, h("li", null, "one"), h("li", null, "two")),
  );
  const after = h(
    "div",
    { id: "app", "data-ready": true },
    h("h1", null, "New title"),
    h("ul", { class: "list wide" }, h("li", null, "one"), h("li", null, "TWO"), h("li", null, "three")),
  );
  const host = patch(render(before), diff(before, after));
  assert.equal(toHtml(host), toHtml(render(after)));
});
