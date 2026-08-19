import test from "node:test";
import assert from "node:assert/strict";
import { renderMarkdown } from "./markdown.mjs";

const eq = (input, expected, msg) =>
  assert.equal(renderMarkdown(input).trimEnd(), expected, msg);

test("hash without a space is not a heading", () => {
  eq("#NoSpace heading", "<p>#NoSpace heading</p>");
  eq("####### seven", "<p>####### seven</p>");
});

test("thematic break variants", () => {
  eq("***\n\n- - -\n\n___", "<hr />\n<hr />\n<hr />");
});

test("thematic break beats list interpretation", () => {
  eq(
    "- item one\n- - -\n- item two",
    "<ul>\n<li>item one</li>\n</ul>\n<hr />\n<ul>\n<li>item two</li>\n</ul>",
  );
});

test("unclosed fences run to the end of input", () => {
  eq(
    "para\n\n```txt\nline one\nline two",
    '<p>para</p>\n<pre><code class="language-txt">line one\nline two\n</code></pre>',
  );
});

test("empty fences produce an empty code block", () => {
  eq("```\n```", "<pre><code></code></pre>");
});

test("blocks interrupt paragraphs without blank lines", () => {
  eq(
    "text line\n# Head\nmore text\n- li",
    "<p>text line</p>\n<h1>Head</h1>\n<p>more text</p>\n<ul>\n<li>li</li>\n</ul>",
  );
});

test("multi-line paragraphs keep literal newlines", () => {
  eq("line one\nline two", "<p>line one\nline two</p>");
});

test("emphasis nests inside strong", () => {
  eq("**a *b* c**", "<p><strong>a <em>b</em> c</strong></p>");
});

test("underscores never emphasize", () => {
  eq("snake_case_name and _underscored_", "<p>snake_case_name and _underscored_</p>");
});

test("numbers with parentheses are not ordered lists", () => {
  eq("1) not ordered", "<p>1) not ordered</p>");
});

test("escapes suppress markup", () => {
  eq("\\*literal\\* \\`tick\\` \\[brackets\\]", "<p>*literal* `tick` [brackets]</p>");
  eq("\\# not a heading", "<p># not a heading</p>");
});

test("html is escaped everywhere, including headings and code", () => {
  eq('# a < b & "c"', "<h1>a &lt; b &amp; &quot;c&quot;</h1>");
  eq("`<img>` tag", "<p><code>&lt;img&gt;</code> tag</p>");
});

test("empty input renders to an empty document", () => {
  eq("", "");
  eq("\n\n\n", "");
});

test("non-string input throws TypeError", () => {
  assert.throws(() => renderMarkdown(42), TypeError);
  assert.throws(() => renderMarkdown(null), TypeError);
});
