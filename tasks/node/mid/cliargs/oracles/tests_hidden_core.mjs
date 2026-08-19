import test from "node:test";
import assert from "node:assert/strict";
import { parseArgs } from "./cliargs.mjs";

const spec = {
  options: {
    verbose: { type: "boolean", short: "v", default: false },
    force: { type: "boolean", short: "f" },
    output: { type: "string", short: "o" },
    port: { type: "number", short: "p", default: 8080 },
    tag: { type: "string", short: "t", multiple: true },
  },
};

test("long options with separate and = values", () => {
  const r = parseArgs(spec, ["--output", "dist/app.js", "--port=3000"]);
  assert.equal(r.values.output, "dist/app.js");
  assert.equal(r.values.port, 3000);
});

test("boolean long options and defaults", () => {
  const r = parseArgs(spec, ["--verbose"]);
  assert.equal(r.values.verbose, true);
  assert.equal(r.values.port, 8080, "default applies when absent");
  assert.equal("force" in r.values, false, "no default, not present");
  assert.equal("output" in r.values, false);
});

test("short aliases", () => {
  const r = parseArgs(spec, ["-v", "-o", "out.txt", "-p", "9090"]);
  assert.equal(r.values.verbose, true);
  assert.equal(r.values.output, "out.txt");
  assert.equal(r.values.port, 9090);
});

test("positionals mix with options", () => {
  const r = parseArgs(spec, ["build", "--verbose", "src/main.js"]);
  assert.deepEqual(r.positionals, ["build", "src/main.js"]);
  assert.equal(r.values.verbose, true);
});

test("multiple collects occurrences in order", () => {
  const r = parseArgs(spec, ["--tag", "a", "-t", "b", "--tag=c"]);
  assert.deepEqual(r.values.tag, ["a", "b", "c"]);
});

test("multiple with no occurrences gives empty array", () => {
  const r = parseArgs(spec, []);
  assert.deepEqual(r.values.tag, []);
});

test("last occurrence wins for non-multiple options", () => {
  const r = parseArgs(spec, ["--output", "a.txt", "--output", "b.txt"]);
  assert.equal(r.values.output, "b.txt");
});

test("double dash ends option parsing", () => {
  const r = parseArgs(spec, ["--verbose", "--", "--port", "-f", "plain"]);
  assert.equal(r.values.verbose, true);
  assert.equal(r.values.port, 8080);
  assert.deepEqual(r.positionals, ["--port", "-f", "plain"]);
});
