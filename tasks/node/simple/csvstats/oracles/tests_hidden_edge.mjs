import test from "node:test";
import assert from "node:assert/strict";
import { parseCsv, columnStats } from "./csvstats.mjs";

test("CRLF and mixed line endings", () => {
  const rows = parseCsv("a,b\r\n1,2\r\n3,4\n5,6");
  assert.deepEqual(rows, [
    { a: "1", b: "2" },
    { a: "3", b: "4" },
    { a: "5", b: "6" },
  ]);
});

test("short rows pad with empty strings, long rows drop extras", () => {
  const rows = parseCsv("a,b,c\n1\n1,2,3,4\n");
  assert.deepEqual(rows, [
    { a: "1", b: "", c: "" },
    { a: "1", b: "2", c: "3" },
  ]);
});

test("header-only and empty input give no rows", () => {
  assert.deepEqual(parseCsv("a,b\n"), []);
  assert.deepEqual(parseCsv(""), []);
});

test("unknown column throws RangeError naming it", () => {
  assert.throws(
    () => columnStats("a,b\n1,2\n", "missing"),
    (err) => err instanceof RangeError && err.message.includes("missing"),
  );
});

test("non-numeric and empty cells are skipped", () => {
  const csv = "v\n10\n\nn/a\n 20 \nNaN\nInfinity\n30\n";
  const s = columnStats(csv, "v");
  assert.deepEqual(s, { count: 3, min: 10, max: 30, mean: 20, median: 20 });
});

test("zero numeric cells gives null stats", () => {
  const s = columnStats("v\nfoo\nbar\n", "v");
  assert.deepEqual(s, { count: 0, min: null, max: null, mean: null, median: null });
});

test("even count median averages the middle pair", () => {
  const s = columnStats("v\n1\n2\n3\n10\n", "v");
  assert.equal(s.median, 2.5);
  assert.equal(s.mean, 4);
});

test("non-string input throws TypeError", () => {
  assert.throws(() => parseCsv(null), TypeError);
});
