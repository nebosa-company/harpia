import test from "node:test";
import assert from "node:assert/strict";
import { parseArgs } from "./cliargs.mjs";

const spec = {
  options: {
    verbose: { type: "boolean", short: "v", default: false },
    force: { type: "boolean", short: "f" },
    all: { type: "boolean", short: "a" },
    output: { type: "string", short: "o" },
    port: { type: "number", short: "p" },
  },
};

const codeIs = (code) => (err) => err instanceof Error && err.code === code;

test("short boolean bundling", () => {
  const r = parseArgs(spec, ["-vaf"]);
  assert.equal(r.values.verbose, true);
  assert.equal(r.values.all, true);
  assert.equal(r.values.force, true);
});

test("non-boolean short inside a bundle is MISSING_VALUE", () => {
  assert.throws(() => parseArgs(spec, ["-vo"]), codeIs("MISSING_VALUE"));
});

test("--no- negation for booleans", () => {
  const r = parseArgs(spec, ["--no-verbose", "--no-force"]);
  assert.equal(r.values.verbose, false);
  assert.equal(r.values.force, false);
});

test("--no- on a non-boolean is INVALID_VALUE", () => {
  assert.throws(() => parseArgs(spec, ["--no-output"]), codeIs("INVALID_VALUE"));
});

test("unknown options raise UNKNOWN_OPTION", () => {
  assert.throws(() => parseArgs(spec, ["--wat"]), codeIs("UNKNOWN_OPTION"));
  assert.throws(() => parseArgs(spec, ["-z"]), codeIs("UNKNOWN_OPTION"));
  assert.throws(() => parseArgs(spec, ["-vz"]), codeIs("UNKNOWN_OPTION"));
  assert.throws(() => parseArgs(spec, ["--no-wat"]), codeIs("UNKNOWN_OPTION"));
});

test("missing values raise MISSING_VALUE", () => {
  assert.throws(() => parseArgs(spec, ["--output"]), codeIs("MISSING_VALUE"));
  assert.throws(() => parseArgs(spec, ["-o"]), codeIs("MISSING_VALUE"));
  assert.throws(() => parseArgs(spec, ["--port="]), codeIs("MISSING_VALUE"));
});

test("bad numbers raise INVALID_VALUE", () => {
  assert.throws(() => parseArgs(spec, ["--port", "abc"]), codeIs("INVALID_VALUE"));
  assert.throws(() => parseArgs(spec, ["--port=NaN"]), codeIs("INVALID_VALUE"));
  assert.throws(() => parseArgs(spec, ["--port", "Infinity"]), codeIs("INVALID_VALUE"));
});

test("boolean with =value raises INVALID_VALUE", () => {
  assert.throws(() => parseArgs(spec, ["--verbose=yes"]), codeIs("INVALID_VALUE"));
});

test("values that look like options are still values", () => {
  const r = parseArgs(spec, ["--output", "--weird--", "-p", "0"]);
  assert.equal(r.values.output, "--weird--");
  assert.equal(r.values.port, 0);
});

test("a bare dash is positional", () => {
  const r = parseArgs(spec, ["-", "x"]);
  assert.deepEqual(r.positionals, ["-", "x"]);
});

test("negative numbers as = values", () => {
  const r = parseArgs(spec, ["--port=-1"]);
  assert.equal(r.values.port, -1);
});
