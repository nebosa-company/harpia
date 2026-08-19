import test from "node:test";
import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { renderMarkdown } from "./markdown.mjs";

const names = (await readdir("fixtures"))
  .filter((f) => f.endsWith(".md"))
  .map((f) => f.replace(/\.md$/, ""))
  .sort();

assert.ok(names.length >= 7, "fixture suite must be present");

for (const name of names) {
  test(`fixture: ${name}`, async () => {
    const md = await readFile(`fixtures/${name}.md`, "utf8");
    const expected = await readFile(`fixtures/${name}.html`, "utf8");
    assert.equal(renderMarkdown(md).trimEnd(), expected.trimEnd());
  });
}

test("fixture inputs with CRLF line endings render identically", async () => {
  const md = await readFile("fixtures/mixed.md", "utf8");
  const expected = await readFile("fixtures/mixed.html", "utf8");
  const crlf = md.replace(/\n/g, "\r\n");
  assert.equal(renderMarkdown(crlf).trimEnd(), expected.trimEnd());
});
