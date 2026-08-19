import test from "node:test";
import assert from "node:assert/strict";
import { parseLine, mergeLogs } from "./logmerge.mjs";

test("parseLine extracts the three fields", () => {
  assert.deepEqual(parseLine("2024-05-01T12:00:00.000Z [INFO] server started"), {
    ts: "2024-05-01T12:00:00.000Z",
    level: "INFO",
    message: "server started",
  });
});

test("parseLine rejects malformed lines", () => {
  assert.equal(parseLine("no timestamp [INFO] x"), null);
  assert.equal(parseLine("2024-05-01T12:00:00.000Z [info] lowercase"), null);
  assert.equal(parseLine("2024-05-01T12:00:00.000Z INFO no brackets"), null);
  assert.equal(parseLine("2024-05-01T12:00:00Z [INFO] no millis"), null);
  assert.equal(parseLine("2024-13-01T12:00:00.000Z [INFO] bad month"), null);
});

test("merges two sources into timestamp order", () => {
  const a = [
    "2024-05-01T10:00:00.000Z [INFO] a1",
    "2024-05-01T12:00:00.000Z [INFO] a2",
  ];
  const b = [
    "2024-05-01T11:00:00.000Z [WARN] b1",
    "2024-05-01T13:00:00.000Z [ERROR] b2",
  ];
  assert.deepEqual(mergeLogs([a, b]), [
    "2024-05-01T10:00:00.000Z [INFO] a1",
    "2024-05-01T11:00:00.000Z [WARN] b1",
    "2024-05-01T12:00:00.000Z [INFO] a2",
    "2024-05-01T13:00:00.000Z [ERROR] b2",
  ]);
});

test("malformed lines are dropped from the merge", () => {
  const merged = mergeLogs([
    ["garbage line", "2024-05-01T10:00:00.000Z [INFO] good"],
    ["2024-05-01T09:00:00.000Z [debug] bad level"],
  ]);
  assert.deepEqual(merged, ["2024-05-01T10:00:00.000Z [INFO] good"]);
});
