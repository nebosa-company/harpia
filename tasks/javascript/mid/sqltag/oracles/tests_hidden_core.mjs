import test from "node:test";
import assert from "node:assert/strict";
import { sql, ident, raw, join, escapeLiteral } from "./sqltag.mjs";

test("a value becomes a numbered placeholder", () => {
  const q = sql`SELECT * FROM users WHERE id = ${42}`;
  assert.equal(q.text, "SELECT * FROM users WHERE id = $1");
  assert.deepEqual(q.values, [42]);
});

test("several values are numbered in order", () => {
  const q = sql`SELECT * FROM t WHERE a = ${1} AND b = ${"two"} AND c = ${true}`;
  assert.equal(q.text, "SELECT * FROM t WHERE a = $1 AND b = $2 AND c = $3");
  assert.deepEqual(q.values, [1, "two", true]);
});

test("a template with no values has no placeholders", () => {
  const q = sql`SELECT 1`;
  assert.equal(q.text, "SELECT 1");
  assert.deepEqual(q.values, []);
});

test("literal text is copied verbatim, newlines included", () => {
  const q = sql`SELECT *
  FROM t
  WHERE a = ${1}`;
  assert.equal(q.text, "SELECT *\n  FROM t\n  WHERE a = $1");
});

test("adjacent placeholders stay separate", () => {
  const q = sql`${1}${2}${3}`;
  assert.equal(q.text, "$1$2$3");
  assert.deepEqual(q.values, [1, 2, 3]);
});

test("values are stored untouched", () => {
  const obj = { nested: true };
  const when = new Date(0);
  const q = sql`INSERT INTO t VALUES (${obj}, ${when}, ${null}, ${0})`;
  assert.equal(q.text, "INSERT INTO t VALUES ($1, $2, $3, $4)");
  assert.equal(q.values[0], obj);
  assert.equal(q.values[1], when);
  assert.equal(q.values[2], null);
  assert.equal(q.values[3], 0);
});

test("an injection attempt stays a parameter", () => {
  const hostile = "'; DROP TABLE users; --";
  const q = sql`SELECT * FROM users WHERE name = ${hostile}`;
  assert.equal(q.text, "SELECT * FROM users WHERE name = $1");
  assert.deepEqual(q.values, [hostile]);
  assert.equal(q.text.includes("DROP"), false);
});

test("a nested fragment is spliced in and renumbered", () => {
  const where = sql`status = ${"active"}`;
  const q = sql`SELECT * FROM users WHERE ${where} AND age > ${30}`;
  assert.equal(q.text, "SELECT * FROM users WHERE status = $1 AND age > $2");
  assert.deepEqual(q.values, ["active", 30]);
});

test("a fragment after other values is renumbered upward", () => {
  const where = sql`b = ${"B"}`;
  const q = sql`SELECT * FROM t WHERE a = ${"A"} AND ${where} AND c = ${"C"}`;
  assert.equal(q.text, "SELECT * FROM t WHERE a = $1 AND b = $2 AND c = $3");
  assert.deepEqual(q.values, ["A", "B", "C"]);
});

test("an array expands into a placeholder list", () => {
  const q = sql`SELECT * FROM t WHERE id IN (${[1, 2, 3]})`;
  assert.equal(q.text, "SELECT * FROM t WHERE id IN ($1, $2, $3)");
  assert.deepEqual(q.values, [1, 2, 3]);
});

test("ident quotes an identifier", () => {
  const q = sql`SELECT * FROM ${ident("user table")} WHERE ${ident("id")} = ${1}`;
  assert.equal(q.text, 'SELECT * FROM "user table" WHERE "id" = $1');
  assert.deepEqual(q.values, [1]);
});

test("raw is inserted verbatim", () => {
  const q = sql`SELECT * FROM t ORDER BY ${raw("created_at DESC")} LIMIT ${10}`;
  assert.equal(q.text, "SELECT * FROM t ORDER BY created_at DESC LIMIT $1");
  assert.deepEqual(q.values, [10]);
});

test("join concatenates fragments", () => {
  const conditions = [sql`a = ${1}`, sql`b = ${2}`, sql`c = ${3}`];
  const q = sql`SELECT * FROM t WHERE ${join(conditions, " AND ")}`;
  assert.equal(q.text, "SELECT * FROM t WHERE a = $1 AND b = $2 AND c = $3");
  assert.deepEqual(q.values, [1, 2, 3]);
});

test("escapeLiteral handles the basic types", () => {
  assert.equal(escapeLiteral("plain"), "'plain'");
  assert.equal(escapeLiteral("it's"), "'it''s'");
  assert.equal(escapeLiteral(42), "42");
  assert.equal(escapeLiteral(-1.5), "-1.5");
  assert.equal(escapeLiteral(true), "TRUE");
  assert.equal(escapeLiteral(false), "FALSE");
  assert.equal(escapeLiteral(null), "NULL");
  assert.equal(escapeLiteral(10n), "10");
  assert.equal(escapeLiteral(new Date(0)), "'1970-01-01T00:00:00.000Z'");
});

test("escapeLiteral doubles every quote in a hostile string", () => {
  assert.equal(escapeLiteral("'; DROP TABLE users; --"), "'''; DROP TABLE users; --'");
});

test("a realistic composed query", () => {
  const filters = join(
    [sql`tenant = ${"acme"}`, sql`created > ${"2020-01-01"}`, sql`kind IN (${["a", "b"]})`],
    " AND ",
  );
  const q = sql`
    SELECT ${raw("id, name")} FROM ${ident("orders")}
    WHERE ${filters}
    ORDER BY ${raw("created DESC")}
    LIMIT ${25}`;
  assert.equal(
    q.text.replace(/\s+/g, " ").trim(),
    'SELECT id, name FROM "orders" WHERE tenant = $1 AND created > $2 AND kind IN ($3, $4) ORDER BY created DESC LIMIT $5',
  );
  assert.deepEqual(q.values, ["acme", "2020-01-01", "a", "b", 25]);
});
