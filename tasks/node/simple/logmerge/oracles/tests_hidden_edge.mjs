import test from "node:test";
import assert from "node:assert/strict";
import { parseLine, mergeLogs } from "./logmerge.mjs";

test("cross-source duplicates keep only the first occurrence", () => {
  const shared = "2024-05-01T10:00:00.000Z [INFO] broadcast";
  const merged = mergeLogs([
    [shared, "2024-05-01T10:00:01.000Z [INFO] only-a"],
    [shared, "2024-05-01T10:00:02.000Z [INFO] only-b"],
    [shared],
  ]);
  assert.deepEqual(merged, [
    "2024-05-01T10:00:00.000Z [INFO] broadcast",
    "2024-05-01T10:00:01.000Z [INFO] only-a",
    "2024-05-01T10:00:02.000Z [INFO] only-b",
  ]);
});

test("same-timestamp entries keep concatenated order", () => {
  const merged = mergeLogs([
    ["2024-05-01T10:00:00.000Z [INFO] from-a"],
    ["2024-05-01T10:00:00.000Z [INFO] from-b"],
    ["2024-05-01T10:00:00.000Z [WARN] also-b? no, from-c"],
  ]);
  assert.deepEqual(merged, [
    "2024-05-01T10:00:00.000Z [INFO] from-a",
    "2024-05-01T10:00:00.000Z [INFO] from-b",
    "2024-05-01T10:00:00.000Z [WARN] also-b? no, from-c",
  ]);
});

test("same message at different levels is not a duplicate", () => {
  const merged = mergeLogs([
    ["2024-05-01T10:00:00.000Z [INFO] disk"],
    ["2024-05-01T10:00:00.000Z [WARN] disk"],
  ]);
  assert.equal(merged.length, 2);
});

test("empty messages parse and serialize without trailing space", () => {
  assert.deepEqual(parseLine("2024-05-01T10:00:00.000Z [PING]"), {
    ts: "2024-05-01T10:00:00.000Z",
    level: "PING",
    message: "",
  });
  assert.deepEqual(parseLine("2024-05-01T10:00:00.000Z [PING] "), {
    ts: "2024-05-01T10:00:00.000Z",
    level: "PING",
    message: "",
  });
  const merged = mergeLogs([["2024-05-01T10:00:00.000Z [PING] "]]);
  assert.deepEqual(merged, ["2024-05-01T10:00:00.000Z [PING]"]);
});

test("extra spacing between parts is malformed", () => {
  assert.equal(parseLine("2024-05-01T10:00:00.000Z  [INFO] x"), null);
});

test("non-string input gives null", () => {
  assert.equal(parseLine(null), null);
  assert.equal(parseLine(42), null);
});

test("empty sources merge to an empty array", () => {
  assert.deepEqual(mergeLogs([]), []);
  assert.deepEqual(mergeLogs([[], []]), []);
});
