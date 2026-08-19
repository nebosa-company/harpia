import test from "node:test";
import assert from "node:assert/strict";
import { parseCsv, columnStats } from "./csvstats.mjs";

test("parses simple rows into header-keyed objects", () => {
  const rows = parseCsv("name,age\nAda,36\nAlan,41\n");
  assert.deepEqual(rows, [
    { name: "Ada", age: "36" },
    { name: "Alan", age: "41" },
  ]);
});

test("quoted fields keep commas and doubled quotes", () => {
  const rows = parseCsv('title,note\n"Hello, World","She said ""hi"""\n');
  assert.deepEqual(rows, [{ title: "Hello, World", note: 'She said "hi"' }]);
});

test("quoted fields may span lines", () => {
  const rows = parseCsv('id,body\n1,"line one\nline two"\n2,plain\n');
  assert.deepEqual(rows, [
    { id: "1", body: "line one\nline two" },
    { id: "2", body: "plain" },
  ]);
});

test("basic column stats", () => {
  const csv = "city,temp\na,10\nb,20\nc,30\nd,40\n";
  assert.deepEqual(columnStats(csv, "temp"), {
    count: 4,
    min: 10,
    max: 40,
    mean: 25,
    median: 25,
  });
});

test("odd count median is the middle value", () => {
  const csv = "x\n7\n1\n9\n";
  const s = columnStats(csv, "x");
  assert.equal(s.count, 3);
  assert.equal(s.median, 7);
  assert.equal(s.min, 1);
  assert.equal(s.max, 9);
});
