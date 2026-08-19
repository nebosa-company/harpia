import test from "node:test";
import assert from "node:assert/strict";
import { mkdir, writeFile, rm } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import path from "node:path";
import { bundle } from "./bundler.mjs";

const run = promisify(execFile);

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

async function buildAndLoad(name, files, entry) {
  const dir = await writeFixture(name, files);
  const code = await bundle(path.join(dir, entry));
  await rm(dir, { recursive: true, force: true });
  const outPath = path.resolve(`${name}.bundle.mjs`);
  await writeFile(outPath, code);
  return import(pathToFileURL(outPath).href);
}

test("multi-line default export expressions", async () => {
  const mod = await buildAndLoad(
    "fx-edge-default",
    {
      "main.mjs": [
        "import config from './config.mjs';",
        "export const flagCount = config.flags.length;",
        "export default config.name;",
        "",
      ].join("\n"),
      "config.mjs": [
        "export default {",
        "  name: 'edge',",
        "  flags: ['a', 'b'],",
        "};",
        "",
      ].join("\n"),
    },
    "main.mjs",
  );
  assert.equal(mod.flagCount, 2);
  assert.equal(mod.default, "edge");
});

test("combined default and named import", async () => {
  const mod = await buildAndLoad(
    "fx-edge-combo",
    {
      "main.mjs": [
        "import maker, { unit as u } from './dep.mjs';",
        "export const built = maker(u);",
        "",
      ].join("\n"),
      "dep.mjs": [
        "export const unit = 'meter';",
        "export default function maker(kind) {",
        "  return 'one ' + kind;",
        "}",
        "",
      ].join("\n"),
    },
    "main.mjs",
  );
  assert.equal(mod.built, "one meter");
});

test("missing modules name the specifier", async () => {
  const dir = await writeFixture("fx-edge-missing", {
    "main.mjs": "import { x } from './missing.mjs';\nexport const y = x;\n",
  });
  await assert.rejects(bundle(path.join(dir, "main.mjs")), /\.\/missing\.mjs/);
});

test("cycles are reported", async () => {
  const dir = await writeFixture("fx-edge-cycle", {
    "a.mjs": "import { b } from './b.mjs';\nexport const a = 1;\n",
    "b.mjs": "import { a } from './a.mjs';\nexport const b = 2;\n",
  });
  await assert.rejects(bundle(path.join(dir, "a.mjs")), /cycle/i);
});

test("unsupported forms are rejected", async () => {
  const ns = await writeFixture("fx-edge-ns", {
    "main.mjs": "import * as all from './lib.mjs';\nexport const n = 1;\n",
    "lib.mjs": "export const v = 1;\n",
  });
  await assert.rejects(bundle(path.join(ns, "main.mjs")), /unsupported/i);

  const bare = await writeFixture("fx-edge-bare", {
    "main.mjs": "import fs from 'node:fs';\nexport const n = 1;\n",
  });
  await assert.rejects(bundle(path.join(bare, "main.mjs")), /unsupported/i);

  const reexport = await writeFixture("fx-edge-reexport", {
    "main.mjs": "export { v } from './lib.mjs';\n",
    "lib.mjs": "export const v = 1;\n",
  });
  await assert.rejects(bundle(path.join(reexport, "main.mjs")), /unsupported/i);
});

test("cli writes a working bundle and fails cleanly", async () => {
  const dir = await writeFixture("fx-edge-cli", {
    "main.mjs": [
      "import { double } from './lib.mjs';",
      "export const eight = double(4);",
      "",
    ].join("\n"),
    "lib.mjs": [
      "export function double(n) {",
      "  return n * 2;",
      "}",
      "",
    ].join("\n"),
  });
  const outPath = path.resolve("fx-edge-cli.out.mjs");
  await run(process.execPath, ["cli.mjs", path.join(dir, "main.mjs"), outPath]);
  await rm(dir, { recursive: true, force: true });
  const mod = await import(pathToFileURL(outPath).href);
  assert.equal(mod.eight, 8);

  await assert.rejects(
    run(process.execPath, ["cli.mjs", "no-such-entry.mjs", "unused.out.mjs"]),
    (err) => err.code === 1,
  );
});
