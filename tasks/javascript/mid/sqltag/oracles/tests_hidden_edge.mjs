import test from "node:test";
import assert from "node:assert/strict";
import { sql, ident, raw, join, escapeLiteral } from "./sqltag.mjs";

test("fragments nest several levels deep", () => {
  const inner = sql`x = ${1}`;
  const middle = sql`(${inner} OR y = ${2})`;
  const outer = sql`SELECT * FROM t WHERE ${middle} AND z = ${3}`;
  assert.equal(outer.text, "SELECT * FROM t WHERE (x = $1 OR y = $2) AND z = $3");
  assert.deepEqual(outer.values, [1, 2, 3]);
});

test("a fragment can be reused in two queries without changing", () => {
  const cond = sql`a = ${"A"}`;
  assert.equal(cond.text, "a = $1");
  const first = sql`SELECT 1 WHERE ${cond}`;
  const second = sql`SELECT 2 WHERE b = ${"B"} AND ${cond}`;
  assert.equal(first.text, "SELECT 1 WHERE a = $1");
  assert.deepEqual(first.values, ["A"]);
  assert.equal(second.text, "SELECT 2 WHERE b = $1 AND a = $2");
  assert.deepEqual(second.values, ["B", "A"]);
  assert.equal(cond.text, "a = $1", "the reused fragment is unchanged");
  assert.deepEqual(cond.values, ["A"]);
});

test("the same fragment twice in one query is numbered twice", () => {
  const cond = sql`a = ${1}`;
  const q = sql`SELECT * FROM t WHERE ${cond} OR ${cond}`;
  assert.equal(q.text, "SELECT * FROM t WHERE a = $1 OR a = $2");
  assert.deepEqual(q.values, [1, 1]);
});

test("a fragment with no values nests cleanly", () => {
  const order = sql`ORDER BY id`;
  const q = sql`SELECT * FROM t WHERE a = ${1} ${order}`;
  assert.equal(q.text, "SELECT * FROM t WHERE a = $1 ORDER BY id");
  assert.deepEqual(q.values, [1]);
});

test("arrays may contain fragments", () => {
  const q = sql`SELECT * WHERE id IN (${[1, sql`(SELECT max(id) FROM t WHERE k = ${"k"})`, 3]})`;
  assert.equal(q.text, "SELECT * WHERE id IN ($1, (SELECT max(id) FROM t WHERE k = $2), $3)");
  assert.deepEqual(q.values, [1, "k", 3]);
});

test("an empty array is a RangeError", () => {
  assert.throws(() => sql`WHERE id IN (${[]})`, RangeError);
  assert.throws(() => join([sql`a = ${1}`, []], " AND "), RangeError);
});

test("undefined, functions and symbols are TypeErrors", () => {
  assert.throws(() => sql`a = ${undefined}`, TypeError);
  assert.throws(() => sql`a = ${() => 1}`, TypeError);
  assert.throws(() => sql`a = ${Symbol("s")}`, TypeError);
  assert.throws(() => sql`a IN (${[1, undefined]})`, TypeError);
});

test("null is a legitimate value", () => {
  const q = sql`WHERE a IS NOT DISTINCT FROM ${null}`;
  assert.equal(q.text, "WHERE a IS NOT DISTINCT FROM $1");
  assert.deepEqual(q.values, [null]);
});

test("ident doubles embedded quotes and rejects bad names", () => {
  assert.equal(ident('we"ird').text, '"we""ird"');
  assert.deepEqual(ident("id").values, []);
  for (const bad of ["", null, undefined, 1, {}, Symbol("s")]) {
    assert.throws(() => ident(bad), TypeError, String(bad));
  }
});

test("raw rejects non-strings and keeps dollar signs literal", () => {
  for (const bad of [null, undefined, 1, {}, ["a"]]) {
    assert.throws(() => raw(bad), TypeError, String(bad));
  }
  const q = sql`SELECT ${raw("$body$ text $body$")} , ${1}`;
  assert.deepEqual(q.values, [1]);
  assert.ok(q.text.startsWith("SELECT $body$ text $body$ , "));
  assert.ok(q.text.endsWith("$1"));
});

test("join defaults to a comma separator", () => {
  const q = sql`INSERT INTO t (a, b) VALUES (${join([1, 2])})`;
  assert.equal(q.text, "INSERT INTO t (a, b) VALUES ($1, $2)");
  assert.deepEqual(q.values, [1, 2]);
});

test("join accepts plain values and fragments together", () => {
  const q = sql`SELECT ${join([raw("id"), 5, sql`upper(${"x"})`], " , ")}`;
  assert.equal(q.text, "SELECT id , $1 , upper($2)");
  assert.deepEqual(q.values, [5, "x"]);
});

test("join of an empty list contributes nothing", () => {
  const empty = join([]);
  assert.equal(empty.text, "");
  assert.deepEqual(empty.values, []);
  const q = sql`SELECT 1 ${empty}`;
  assert.equal(q.text, "SELECT 1 ");
  assert.deepEqual(q.values, []);
});

test("join validates its arguments", () => {
  assert.throws(() => join("not an array"), TypeError);
  assert.throws(() => join(null), TypeError);
  assert.throws(() => join([1, 2], 5), TypeError);
});

test("sql refuses to be called as a plain function", () => {
  assert.throws(() => sql("SELECT 1"), TypeError);
  assert.throws(() => sql(["SELECT 1"]), TypeError);
});

test("escapeLiteral rejects what has no literal form", () => {
  for (const bad of [undefined, NaN, Infinity, -Infinity, {}, [1], () => 1, Symbol("s")]) {
    assert.throws(() => escapeLiteral(bad), TypeError, String(bad));
  }
});

test("escapeLiteral handles empty and multi-quote strings", () => {
  assert.equal(escapeLiteral(""), "''");
  assert.equal(escapeLiteral("''"), "''''''");
  assert.equal(escapeLiteral("a'b'c"), "'a''b''c'");
});

test("text is derived, so reading it twice gives the same string", () => {
  const q = sql`SELECT ${1}, ${2}`;
  assert.equal(q.text, q.text);
  assert.equal(q.text, "SELECT $1, $2");
  assert.equal(q.values.length, 2);
});

test("a large query numbers every placeholder", () => {
  const parts = [];
  for (let i = 0; i < 50; i++) parts.push(sql`c${raw(String(i))} = ${i}`);
  const q = sql`SELECT * FROM t WHERE ${join(parts, " AND ")}`;
  assert.equal(q.values.length, 50);
  assert.ok(q.text.includes("c0 = $1"));
  assert.ok(q.text.includes("c49 = $50"));
  assert.deepEqual(
    q.values,
    Array.from({ length: 50 }, (_, i) => i),
  );
});
