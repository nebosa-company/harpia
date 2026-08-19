import { test } from "node:test";
import assert from "node:assert/strict";
import { amountOf, decode, summarize } from "../src/report";

test("decode reads the three well-formed shapes", () => {
  assert.deepEqual(decode("sale|10|eu"), { kind: "sale", amount: 10, region: "eu" });
  assert.deepEqual(decode("refund|4.5|damaged"), {
    kind: "refund",
    amount: 4.5,
    reason: "damaged",
  });
  assert.deepEqual(decode("adjustment|-2|rounding"), {
    kind: "adjustment",
    delta: -2,
    note: "rounding",
  });
});

test("decode trims the third field", () => {
  assert.deepEqual(decode("sale|1|  eu  "), { kind: "sale", amount: 1, region: "eu" });
});

test("decode rejects malformed lines", () => {
  assert.equal(decode(""), null);
  assert.equal(decode("sale"), null);
  assert.equal(decode("sale|10"), null);
  assert.equal(decode("sale|10|eu|extra"), null);
  assert.equal(decode("transfer|10|eu"), null);
  assert.equal(decode("Sale|10|eu"), null);
  assert.equal(decode("sale|abc|eu"), null);
  assert.equal(decode("sale|Infinity|eu"), null);
  assert.equal(decode("sale|1e999|eu"), null);
  assert.equal(decode("sale|NaN|eu"), null);
  assert.equal(decode("sale|10|"), null);
  assert.equal(decode("sale|10|   "), null);
});

test("amountOf signs each kind", () => {
  assert.equal(amountOf({ kind: "sale", amount: 10, region: "eu" }), 10);
  assert.equal(amountOf({ kind: "refund", amount: 4, reason: "x" }), -4);
  assert.equal(amountOf({ kind: "adjustment", delta: -2.5, note: "x" }), -2.5);
  assert.equal(amountOf({ kind: "adjustment", delta: 3, note: "x" }), 3);
});

test("a refund lowers the net total", () => {
  const s = summarize(["sale|10|eu", "refund|4|damaged"]);
  assert.equal(s.net, 6);
});

test("an adjustment does not poison the total", () => {
  const s = summarize(["sale|10|eu", "adjustment|-2.5|rounding"]);
  assert.equal(s.net, 7.5);
  assert.equal(Number.isNaN(s.net), false);
});

test("regions are sale-only, de-duplicated and sorted", () => {
  const s = summarize([
    "sale|1|uk",
    "refund|1|damaged",
    "sale|1|eu",
    "adjustment|1|note",
    "sale|1|uk",
    "sale|1|apac",
  ]);
  assert.deepEqual(s.regions, ["apac", "eu", "uk"]);
});

test("counts cover every kind and skipped counts the rest", () => {
  const s = summarize([
    "sale|1|eu",
    "sale|2|eu",
    "refund|1|x",
    "adjustment|1|y",
    "garbage",
    "transfer|1|z",
  ]);
  assert.deepEqual(s.counts, { sale: 2, refund: 1, adjustment: 1 });
  assert.equal(s.skipped, 2);
});

test("an empty report is all zeroes", () => {
  const s = summarize([]);
  assert.deepEqual(s, {
    net: 0,
    counts: { sale: 0, refund: 0, adjustment: 0 },
    regions: [],
    skipped: 0,
  });
});

test("a report of only bad lines is all skipped", () => {
  const s = summarize(["", "x", "sale|nope|eu"]);
  assert.equal(s.skipped, 3);
  assert.equal(s.net, 0);
  assert.deepEqual(s.regions, []);
});

test("the net total is rounded to two decimals", () => {
  const s = summarize(["sale|0.1|eu", "sale|0.2|eu"]);
  assert.equal(s.net, 0.3);
});
