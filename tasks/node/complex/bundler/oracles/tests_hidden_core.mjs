import test from "node:test";
import assert from "node:assert/strict";
import { mkdir, writeFile, rm } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import path from "node:path";
import { bundle } from "./bundler.mjs";

async function writeFixture(name, files) {
  const dir = path.resolve(name);
  await rm(dir, { recursive: true, force: true });
  await mkdir(dir, { recursive: true });
  for (const [rel, content] of Object.entries(files)) {
    const p = path.join(dir, rel);
    await mkdir(path.dirname(p), { recursive: true });
    await writeFile(p, content);
  }
  return dir;
}

// Bundles entry, DELETES the sources, then imports the bundle: the output
// must be fully self-contained.
async function buildAndLoad(name, files, entry) {
  const dir = await writeFixture(name, files);
  const code = await bundle(path.join(dir, entry));
  await rm(dir, { recursive: true, force: true });
  const outPath = path.resolve(`${name}.bundle.mjs`);
  await writeFile(outPath, code);
  return import(pathToFileURL(outPath).href);
}

test("values flow through a three-module graph", async () => {
  const mod = await buildAndLoad(
    "fx-core-graph",
    {
      "main.mjs": [
        "import { add, SCALE } from './math.mjs';",
        "import greet from './greet.mjs';",
        "",
        "export const total = add(2, 3) * SCALE;",
        "export const message = greet('bundler');",
        "export default { total, message };",
        "",
      ].join("\n"),
      "math.mjs": [
        "export const SCALE = 10;",
        "export function add(a, b) {",
        "  return a + b;",
        "}",
        "",
      ].join("\n"),
      "greet.mjs": [
        "import { add } from './math.mjs';",
        "",
        "export default function greet(name) {",
        "  return 'hello ' + name + ' #' + add(1, 1);",
        "}",
        "",
      ].join("\n"),
    },
    "main.mjs",
  );
  assert.equal(mod.total, 50);
  assert.equal(mod.message, "hello bundler #2");
  assert.deepEqual(mod.default, { total: 50, message: "hello bundler #2" });
});

test("diamond dependencies evaluate once and share state", async () => {
  const mod = await buildAndLoad(
    "fx-core-diamond",
    {
      "main.mjs": [
        "import { l } from './left.mjs';",
        "import { r } from './right.mjs';",
        "import { registry } from './state.mjs';",
        "",
        "export const seen = [...registry];",
        "export const counts = { l, r };",
        "",
      ].join("\n"),
      "left.mjs": [
        "import { record } from './state.mjs';",
        "export const l = record('left');",
        "",
      ].join("\n"),
      "right.mjs": [
        "import { record } from './state.mjs';",
        "export const r = record('right');",
        "",
      ].join("\n"),
      "state.mjs": [
        "globalThis.__probeDiamond = (globalThis.__probeDiamond ?? 0) + 1;",
        "",
        "export const registry = [];",
        "export function record(tag) {",
        "  registry.push(tag);",
        "  return registry.length;",
        "}",
        "",
      ].join("\n"),
    },
    "main.mjs",
  );
  assert.equal(globalThis.__probeDiamond, 1, "shared module must run once");
  assert.deepEqual(mod.seen, ["left", "right"]);
  assert.deepEqual(mod.counts, { l: 1, r: 2 });
});

test("side-effect ordering is deps-first in import order", async () => {
  await buildAndLoad(
    "fx-core-order",
    {
      "a.mjs": [
        "import './b.mjs';",
        "import './c.mjs';",
        "(globalThis.__probeOrder ??= []).push('a');",
        "",
      ].join("\n"),
      "b.mjs": [
        "import './d.mjs';",
        "(globalThis.__probeOrder ??= []).push('b');",
        "",
      ].join("\n"),
      "c.mjs": [
        "import './d.mjs';",
        "(globalThis.__probeOrder ??= []).push('c');",
        "",
      ].join("\n"),
      "d.mjs": ["(globalThis.__probeOrder ??= []).push('d');", ""].join("\n"),
    },
    "a.mjs",
  );
  assert.deepEqual(globalThis.__probeOrder, ["d", "b", "c", "a"]);
});

test("export lists with renames and import renames", async () => {
  const mod = await buildAndLoad(
    "fx-core-renames",
    {
      "main.mjs": [
        "import { base, bump as inc } from './lib.mjs';",
        "",
        "export const answer = inc(base);",
        "",
      ].join("\n"),
      "lib.mjs": [
        "const secret = 41;",
        "function bump(n) {",
        "  return n + 1;",
        "}",
        "export { secret as base, bump };",
        "",
      ].join("\n"),
    },
    "main.mjs",
  );
  assert.equal(mod.answer, 42);
});

test("subdirectory resolution with ../ specifiers", async () => {
  const mod = await buildAndLoad(
    "fx-core-subdir",
    {
      "main.mjs": [
        "import { tagged } from './nested/deep.mjs';",
        "export const out = tagged('x');",
        "",
      ].join("\n"),
      "nested/deep.mjs": [
        "import { prefix } from '../common.mjs';",
        "export function tagged(s) {",
        "  return prefix + s;",
        "}",
        "",
      ].join("\n"),
      "common.mjs": ["export const prefix = 'tag:';", ""].join("\n"),
    },
    "main.mjs",
  );
  assert.equal(mod.out, "tag:x");
});
