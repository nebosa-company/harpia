import { test } from "node:test";
import assert from "node:assert/strict";
import {
  LEVELS,
  Level,
  Priority,
  compareLevels,
  enumNames,
  enumValues,
  isLevel,
  levelName,
  toLevel,
} from "../src/enum-union";

test("the enums keep their members and values", () => {
  assert.equal(Level.Trace, "trace");
  assert.equal(Level.Error, "error");
  assert.equal(Priority.Low, 1);
  assert.equal(Priority.Normal, 5);
  assert.equal(Priority.High, 10);
});

test("LEVELS lists every member in declaration order", () => {
  assert.deepEqual([...LEVELS], ["trace", "debug", "info", "warn", "error"]);
});

test("isLevel accepts member values only", () => {
  assert.equal(isLevel("trace"), true);
  assert.equal(isLevel("error"), true);
  assert.equal(isLevel("Trace"), false);
  assert.equal(isLevel("fatal"), false);
  assert.equal(isLevel(""), false);
  assert.equal(isLevel(1), false);
  assert.equal(isLevel(null), false);
  assert.equal(isLevel(undefined), false);
  assert.equal(isLevel(Level.Warn), true);
});

test("toLevel maps wire strings back to members", () => {
  assert.equal(toLevel("info"), Level.Info);
  assert.equal(toLevel("warn"), Level.Warn);
  assert.equal(toLevel("Info"), undefined);
  assert.equal(toLevel("nope"), undefined);
  assert.equal(toLevel(""), undefined);
});

test("levelName gives the member name", () => {
  assert.equal(levelName(Level.Trace), "Trace");
  assert.equal(levelName(Level.Debug), "Debug");
  assert.equal(levelName(Level.Info), "Info");
  assert.equal(levelName(Level.Warn), "Warn");
  assert.equal(levelName(Level.Error), "Error");
});

test("compareLevels orders by severity", () => {
  assert.ok(compareLevels(Level.Trace, Level.Error) < 0);
  assert.ok(compareLevels(Level.Error, Level.Trace) > 0);
  assert.equal(compareLevels(Level.Info, Level.Info), 0);
  assert.ok(compareLevels(Level.Debug, Level.Info) < 0);
  assert.ok(compareLevels(Level.Warn, Level.Info) > 0);
});

test("compareLevels works as a sort comparator", () => {
  const shuffled = [Level.Warn, Level.Trace, Level.Error, Level.Info, Level.Debug];
  assert.deepEqual(shuffled.slice().sort(compareLevels), [
    Level.Trace,
    Level.Debug,
    Level.Info,
    Level.Warn,
    Level.Error,
  ]);
});

test("enumNames and enumValues read a string enum", () => {
  assert.deepEqual(enumNames(Level), ["Trace", "Debug", "Info", "Warn", "Error"]);
  assert.deepEqual(enumValues(Level), ["trace", "debug", "info", "warn", "error"]);
});

test("enumNames and enumValues drop a numeric enum's reverse mapping", () => {
  assert.deepEqual(enumNames(Priority), ["Low", "Normal", "High"]);
  assert.deepEqual(enumValues(Priority), [1, 5, 10]);
});

test("the numeric enum really does carry a reverse mapping", () => {
  const raw = Priority as unknown as Record<string, unknown>;
  assert.equal(raw["1"], "Low");
  assert.equal(Object.keys(raw).length, 6);
});
