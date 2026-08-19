import test from "node:test";
import assert from "node:assert/strict";
import { h, render, diff, patch, toHtml } from "./vdom.mjs";

const list = (...keys) => h("ul", null, ...keys.map((k) => h("li", { key: k }, k.toUpperCase())));

test("reordering keyed children never replaces them", () => {
  const before = list("a", "b", "c");
  const after = list("c", "a", "b");
  const ops = diff(before, after);
  assert.equal(
    ops.some((o) => ["replace", "insert", "remove"].includes(o.op)),
    false,
    `unexpected ops: ${ops.map((o) => o.op).join(",")}`,
  );
  assert.ok(ops.some((o) => o.op === "move"));
});

test("reordering keeps the host node objects", () => {
  const before = list("a", "b", "c");
  const after = list("c", "a", "b");
  const host = render(before);
  const [nodeA, nodeB, nodeC] = host.children;
  const result = patch(host, diff(before, after));
  assert.equal(result.children[0], nodeC);
  assert.equal(result.children[1], nodeA);
  assert.equal(result.children[2], nodeB);
  assert.equal(toHtml(result), toHtml(render(after)));
});

test("reversing a keyed list works", () => {
  const before = list("a", "b", "c", "d");
  const after = list("d", "c", "b", "a");
  const host = render(before);
  const originals = [...host.children];
  const result = patch(host, diff(before, after));
  assert.equal(toHtml(result), toHtml(render(after)));
  assert.deepEqual(result.children, [originals[3], originals[2], originals[1], originals[0]]);
});

test("inserting into the middle of a keyed list keeps the neighbours", () => {
  const before = list("a", "c");
  const after = list("a", "b", "c");
  const host = render(before);
  const [nodeA, nodeC] = host.children;
  const result = patch(host, diff(before, after));
  assert.equal(result.children[0], nodeA);
  assert.equal(result.children[2], nodeC);
  assert.equal(toHtml(result), toHtml(render(after)));
});

test("removing from the middle of a keyed list keeps the rest", () => {
  const before = list("a", "b", "c");
  const after = list("a", "c");
  const host = render(before);
  const [nodeA, , nodeC] = host.children;
  const result = patch(host, diff(before, after));
  assert.deepEqual(result.children, [nodeA, nodeC]);
  assert.equal(toHtml(result), toHtml(render(after)));
});

test("a keyed list can be rebuilt entirely", () => {
  const before = list("a", "b");
  const after = list("x", "y", "z");
  const host = patch(render(before), diff(before, after));
  assert.equal(toHtml(host), toHtml(render(after)));
});

test("keyed children are patched in place when their content changes", () => {
  const before = h("ul", null, h("li", { key: "a" }, "one"), h("li", { key: "b", class: "old" }, "two"));
  const after = h("ul", null, h("li", { key: "b", class: "new" }, "TWO"), h("li", { key: "a" }, "one"));
  const host = render(before);
  const nodeB = host.children[1];
  const result = patch(host, diff(before, after));
  assert.equal(result.children[0], nodeB, "the moved node is the same object");
  assert.equal(toHtml(result), toHtml(render(after)));
  assert.deepEqual(nodeB.attrs, { class: "new" });
});

test("a keyed move plus a nested change round-trips", () => {
  const before = h(
    "div",
    null,
    h("ul", null, h("li", { key: 1 }, h("span", null, "one")), h("li", { key: 2 }, h("span", null, "two"))),
  );
  const after = h(
    "div",
    null,
    h("ul", null, h("li", { key: 2 }, h("span", null, "TWO")), h("li", { key: 1 }, h("span", null, "one"))),
  );
  const host = patch(render(before), diff(before, after));
  assert.equal(toHtml(host), toHtml(render(after)));
});

test("unkeyed children are compared position by position", () => {
  const before = h("ul", null, h("li", null, "a"), h("li", null, "b"));
  const after = h("ul", null, h("li", null, "b"), h("li", null, "a"));
  const ops = diff(before, after);
  assert.equal(
    ops.every((o) => o.op === "text"),
    true,
    `unexpected ops: ${ops.map((o) => o.op).join(",")}`,
  );
  assert.equal(toHtml(patch(render(before), ops)), toHtml(render(after)));
});

test("a prop set to false or null is removed", () => {
  const before = h("input", { disabled: true, value: "x", title: "t" });
  const after = h("input", { disabled: false, value: null, title: "t" });
  const host = patch(render(before), diff(before, after));
  assert.deepEqual(host.attrs, { title: "t" });
  assert.equal(toHtml(host), '<input title="t"></input>');
});

test("text becomes an element and back", () => {
  const text = h("div", null, "plain");
  const element = h("div", null, h("b", null, "bold"));
  const toElement = patch(render(text), diff(text, element));
  assert.equal(toHtml(toElement), "<div><b>bold</b></div>");
  const toText = patch(render(element), diff(element, text));
  assert.equal(toHtml(toText), "<div>plain</div>");
});

test("emptying and refilling children", () => {
  const full = h("div", null, h("p", null, "a"), h("p", null, "b"));
  const empty = h("div", null);
  const emptied = patch(render(full), diff(full, empty));
  assert.equal(toHtml(emptied), "<div></div>");
  const refilled = patch(render(empty), diff(empty, full));
  assert.equal(toHtml(refilled), "<div><p>a</p><p>b</p></div>");
});

test("deep trees keep their paths straight", () => {
  const build = (leaf) =>
    h("a1", null, h("b1", null, h("c1", null, h("d1", { mark: leaf }, leaf))), h("b2", null, "sibling"));
  const before = build("old");
  const after = build("new");
  const ops = diff(before, after);
  assert.deepEqual(
    ops.map((o) => o.path.join(".")).sort(),
    ["0.0.0", "0.0.0.0"],
  );
  assert.equal(toHtml(patch(render(before), ops)), toHtml(render(after)));
});

test("patch leaves the operation list alone", () => {
  const before = h("div", { a: 1 }, h("p", null, "x"));
  const after = h("div", { a: 2 }, h("p", null, "y"));
  const ops = diff(before, after);
  const snapshot = JSON.stringify(ops);
  const count = ops.length;
  patch(render(before), ops);
  assert.equal(ops.length, count);
  assert.equal(JSON.stringify(ops), snapshot);
});

test("the same operations apply to a second rendered copy", () => {
  const before = list("a", "b", "c");
  const after = list("b", "c", "a");
  const ops = diff(before, after);
  const first = patch(render(before), ops);
  const second = patch(render(before), ops);
  assert.equal(toHtml(first), toHtml(second));
  assert.equal(toHtml(first), toHtml(render(after)));
});

test("attribute values are escaped", () => {
  const host = render(h("div", { title: 'a "quoted" & <angled>' }));
  assert.equal(toHtml(host), '<div title="a &quot;quoted&quot; &amp; &lt;angled&gt;"></div>');
});

test("diff, patch and render validate their arguments", () => {
  const node = h("div", null);
  assert.throws(() => diff("text", node), TypeError);
  assert.throws(() => diff(node, null), TypeError);
  assert.throws(() => diff({ type: "div" }, node), TypeError);
  assert.throws(() => patch(null, []), TypeError);
  assert.throws(() => patch(render(node), "nope"), TypeError);
  assert.throws(() => render(null), TypeError);
  assert.throws(() => render(42), TypeError);
});

test("numeric keys behave like string keys", () => {
  const before = h("ul", null, h("li", { key: 1 }, "one"), h("li", { key: 2 }, "two"));
  const after = h("ul", null, h("li", { key: 2 }, "two"), h("li", { key: 1 }, "one"));
  const host = render(before);
  const first = host.children[0];
  const result = patch(host, diff(before, after));
  assert.equal(result.children[1], first);
  assert.equal(toHtml(result), "<ul><li>two</li><li>one</li></ul>");
});

test("a large keyed shuffle still lands correctly", () => {
  const keys = Array.from({ length: 30 }, (_, i) => `k${i}`);
  const before = list(...keys);
  const shuffled = [...keys.slice(15), ...keys.slice(0, 15)].reverse();
  const after = list(...shuffled);
  const host = render(before);
  const byKey = new Map(keys.map((k, i) => [k, host.children[i]]));
  const result = patch(host, diff(before, after));
  assert.equal(toHtml(result), toHtml(render(after)));
  shuffled.forEach((k, i) => {
    assert.equal(result.children[i], byKey.get(k), `node for ${k} was rebuilt`);
  });
});
