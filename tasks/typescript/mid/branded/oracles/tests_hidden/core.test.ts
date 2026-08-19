import { test } from "node:test";
import assert from "node:assert/strict";
import {
  addMetres,
  addSeconds,
  compare,
  metres,
  metresPerSecond,
  scaleMetres,
  seconds,
  speed,
  subtractMetres,
  toNumber,
  travelled,
} from "../src/units";

const rangeError = (message: string) => (err: unknown) =>
  err instanceof RangeError && err.message === message;

test("constructors keep the numeric value", () => {
  assert.equal(toNumber(metres(3)), 3);
  assert.equal(toNumber(seconds(0)), 0);
  assert.equal(toNumber(metresPerSecond(-2.5)), -2.5);
  assert.equal(toNumber(metres(-4)), -4);
});

test("a branded value is still a number at run time", () => {
  assert.equal(typeof metres(3), "number");
  assert.equal(metres(3) + 1, 4);
});

test("constructors reject non-finite input", () => {
  assert.throws(() => metres(Number.NaN), rangeError("metres must be finite"));
  assert.throws(
    () => metres(Number.POSITIVE_INFINITY),
    rangeError("metres must be finite"),
  );
  assert.throws(() => seconds(Number.NaN), rangeError("seconds must be finite"));
  assert.throws(
    () => metresPerSecond(Number.NEGATIVE_INFINITY),
    rangeError("metresPerSecond must be finite"),
  );
});

test("seconds refuse to go negative", () => {
  assert.throws(() => seconds(-1), rangeError("seconds must not be negative"));
  assert.equal(toNumber(seconds(0)), 0);
});

test("distance arithmetic", () => {
  assert.equal(toNumber(addMetres(metres(3), metres(4))), 7);
  assert.equal(toNumber(subtractMetres(metres(3), metres(4))), -1);
  assert.equal(toNumber(scaleMetres(metres(3), 2.5)), 7.5);
  assert.equal(toNumber(scaleMetres(metres(3), 0)), 0);
  assert.equal(toNumber(scaleMetres(metres(3), -1)), -3);
});

test("scaleMetres rejects a non-finite factor", () => {
  assert.throws(
    () => scaleMetres(metres(3), Number.NaN),
    rangeError("metres must be finite"),
  );
  assert.throws(
    () => scaleMetres(metres(3), Number.POSITIVE_INFINITY),
    rangeError("metres must be finite"),
  );
});

test("duration arithmetic", () => {
  assert.equal(toNumber(addSeconds(seconds(1), seconds(2))), 3);
  assert.equal(toNumber(addSeconds(seconds(0), seconds(0))), 0);
});

test("speed divides and guards the zero duration", () => {
  assert.equal(toNumber(speed(metres(10), seconds(2))), 5);
  assert.equal(toNumber(speed(metres(-10), seconds(4))), -2.5);
  assert.throws(
    () => speed(metres(10), seconds(0)),
    rangeError("time must be greater than zero"),
  );
});

test("travelled multiplies back", () => {
  assert.equal(toNumber(travelled(metresPerSecond(5), seconds(3))), 15);
  assert.equal(toNumber(travelled(metresPerSecond(0), seconds(3))), 0);
});

test("an arithmetic result that is not finite is refused", () => {
  const huge = metres(Number.MAX_VALUE);
  assert.throws(() => addMetres(huge, huge), rangeError("metres must be finite"));
  assert.throws(
    () => scaleMetres(huge, Number.MAX_VALUE),
    rangeError("metres must be finite"),
  );
});

test("compare sorts distances", () => {
  const list = [metres(3), metres(-1), metres(10), metres(0)];
  assert.deepEqual(list.slice().sort(compare).map(toNumber), [-1, 0, 3, 10]);
  assert.equal(compare(metres(1), metres(1)), 0);
  assert.ok(compare(metres(1), metres(2)) < 0);
  assert.ok(compare(metres(2), metres(1)) > 0);
});

test("a full round trip", () => {
  const distance = addMetres(metres(120), metres(80));
  const time = addSeconds(seconds(5), seconds(5));
  const rate = speed(distance, time);
  assert.equal(toNumber(rate), 20);
  assert.equal(toNumber(travelled(rate, time)), 200);
});
