import { test } from "node:test";
import assert from "node:assert/strict";
import { createDatabase } from "../src/query";

type Shop = {
  users: { id: number; name: string; age: number; active: boolean; note: string | null };
  orders: { id: number; userId: number; total: number };
};

const seed = () => ({
  users: [
    { id: 1, name: "ada", age: 36, active: true, note: null },
    { id: 2, name: "grace", age: 45, active: false, note: "vip" },
    { id: 3, name: "alan", age: 36, active: true, note: "o'brien" },
    { id: 4, name: "edsger", age: 72, active: false, note: null },
  ],
  orders: [
    { id: 10, userId: 1, total: 100 },
    { id: 11, userId: 2, total: 250 },
    { id: 12, userId: 1, total: 50 },
  ],
});

const db = () => createDatabase<Shop>(seed());

test("an unfiltered query returns every row, copied", () => {
  const data = seed();
  const rows = createDatabase<Shop>(data).from("orders").run();
  assert.deepEqual(rows, data.orders);
  assert.notEqual(rows[0], data.orders[0]);
});

test("select narrows the projected columns", () => {
  const rows = db().from("users").select("id", "name").run();
  assert.deepEqual(rows, [
    { id: 1, name: "ada" },
    { id: 2, name: "grace" },
    { id: 3, name: "alan" },
    { id: 4, name: "edsger" },
  ]);
  assert.deepEqual(Object.keys(rows[0]), ["id", "name"]);
});

test("select keeps the order the columns were given in", () => {
  const rows = db().from("users").select("name", "id").run();
  assert.deepEqual(Object.keys(rows[0]), ["name", "id"]);
});

test("where filters with each operator", () => {
  const users = db().from("users");
  assert.deepEqual(users.where("age", ">", 40).select("id").run(), [
    { id: 2 },
    { id: 4 },
  ]);
  assert.deepEqual(users.where("age", ">=", 45).select("id").run(), [
    { id: 2 },
    { id: 4 },
  ]);
  assert.deepEqual(users.where("age", "<", 40).select("id").run(), [
    { id: 1 },
    { id: 3 },
  ]);
  assert.deepEqual(users.where("age", "<=", 36).select("id").run(), [
    { id: 1 },
    { id: 3 },
  ]);
  assert.deepEqual(users.where("name", "=", "alan").select("id").run(), [{ id: 3 }]);
  assert.deepEqual(users.where("active", "!=", true).select("id").run(), [
    { id: 2 },
    { id: 4 },
  ]);
  assert.deepEqual(users.where("note", "=", null).select("id").run(), [
    { id: 1 },
    { id: 4 },
  ]);
});

test("where clauses are ANDed", () => {
  const rows = db()
    .from("users")
    .where("age", "=", 36)
    .where("name", "=", "ada")
    .select("id")
    .run();
  assert.deepEqual(rows, [{ id: 1 }]);
});

test("orderBy sorts, defaults to ascending, and chains", () => {
  assert.deepEqual(
    db().from("users").orderBy("name").select("name").run(),
    [{ name: "ada" }, { name: "alan" }, { name: "edsger" }, { name: "grace" }],
  );
  assert.deepEqual(
    db().from("users").orderBy("age", "desc").select("id").run(),
    [{ id: 4 }, { id: 2 }, { id: 1 }, { id: 3 }],
  );
  assert.deepEqual(
    db().from("users").orderBy("age", "asc").orderBy("name", "desc").select("id").run(),
    [{ id: 3 }, { id: 1 }, { id: 2 }, { id: 4 }],
  );
});

test("sorting is stable for rows that compare equal", () => {
  assert.deepEqual(db().from("users").orderBy("active").select("id").run(), [
    { id: 2 },
    { id: 4 },
    { id: 1 },
    { id: 3 },
  ]);
});

test("offset is applied before limit", () => {
  const users = db().from("users").orderBy("id");
  assert.deepEqual(users.limit(2).select("id").run(), [{ id: 1 }, { id: 2 }]);
  assert.deepEqual(users.offset(1).select("id").run(), [
    { id: 2 },
    { id: 3 },
    { id: 4 },
  ]);
  assert.deepEqual(users.offset(1).limit(2).select("id").run(), [{ id: 2 }, { id: 3 }]);
  assert.deepEqual(users.limit(2).offset(1).select("id").run(), [{ id: 2 }, { id: 3 }]);
  assert.deepEqual(users.offset(10).select("id").run(), []);
});

test("every builder method returns a fresh query", () => {
  const base = db().from("users");
  const filtered = base.where("age", ">", 40);
  assert.equal(base.run().length, 4);
  assert.equal(filtered.run().length, 2);
  assert.notEqual(base, filtered);
  assert.equal(base.toSql(), "SELECT * FROM users");
});

test("the source rows are never mutated", () => {
  const data = seed();
  const built = createDatabase<Shop>(data);
  const rows = built.from("users").select("id").run();
  (rows[0] as { id: number }).id = 999;
  assert.equal(data.users[0].id, 1);
});

test("toSql renders the whole statement", () => {
  assert.equal(db().from("users").toSql(), "SELECT * FROM users");
  assert.equal(
    db().from("users").select("id", "name").toSql(),
    "SELECT id, name FROM users",
  );
  assert.equal(
    db().from("users").where("age", ">", 40).toSql(),
    "SELECT * FROM users WHERE age > 40",
  );
  assert.equal(
    db().from("users").where("age", ">", 40).where("active", "=", true).toSql(),
    "SELECT * FROM users WHERE age > 40 AND active = TRUE",
  );
  assert.equal(
    db().from("users").where("active", "=", false).toSql(),
    "SELECT * FROM users WHERE active = FALSE",
  );
  assert.equal(
    db().from("users").where("name", "=", "ada").toSql(),
    "SELECT * FROM users WHERE name = 'ada'",
  );
  assert.equal(
    db().from("users").where("note", "=", "o'brien").toSql(),
    "SELECT * FROM users WHERE note = 'o''brien'",
  );
  assert.equal(
    db().from("users").where("note", "=", null).toSql(),
    "SELECT * FROM users WHERE note IS NULL",
  );
  assert.equal(
    db().from("users").where("note", "!=", null).toSql(),
    "SELECT * FROM users WHERE note IS NOT NULL",
  );
});

test("toSql renders ordering, limit and offset", () => {
  assert.equal(
    db().from("users").orderBy("name").toSql(),
    "SELECT * FROM users ORDER BY name ASC",
  );
  assert.equal(
    db().from("users").orderBy("age", "desc").orderBy("name").toSql(),
    "SELECT * FROM users ORDER BY age DESC, name ASC",
  );
  assert.equal(db().from("users").limit(5).toSql(), "SELECT * FROM users LIMIT 5");
  assert.equal(db().from("users").offset(2).toSql(), "SELECT * FROM users OFFSET 2");
  assert.equal(
    db()
      .from("users")
      .select("id", "name")
      .where("age", ">=", 36)
      .orderBy("name", "desc")
      .limit(2)
      .offset(1)
      .toSql(),
    "SELECT id, name FROM users WHERE age >= 36 ORDER BY name DESC LIMIT 2 OFFSET 1",
  );
});

test("an unknown table is a RangeError", () => {
  const built = db() as unknown as { from(table: string): { run(): unknown } };
  assert.throws(
    () => built.from("ghosts").run(),
    (err: unknown) =>
      err instanceof RangeError && err.message === "unknown table: ghosts",
  );
});

test("a full query composes filtering, ordering, paging and projection", () => {
  const rows = db()
    .from("users")
    .where("age", ">=", 36)
    .orderBy("age", "desc")
    .orderBy("name", "asc")
    .offset(1)
    .limit(2)
    .select("name", "age")
    .run();
  assert.deepEqual(rows, [
    { name: "grace", age: 45 },
    { name: "ada", age: 36 },
  ]);
});
