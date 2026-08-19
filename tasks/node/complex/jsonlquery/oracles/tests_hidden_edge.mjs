import test from "node:test";
import assert from "node:assert/strict";
import { writeFile, rm } from "node:fs/promises";
import { JsonlDatabase } from "./jsonldb.mjs";

function makeDataset() {
  let s = 42 >>> 0;
  const rand = () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
  const statuses = ["active", "idle", "banned", "new"];
  const regions = ["eu", "us", "apac"];
  const records = [];
  for (let i = 0; i < 1000; i++) {
    const rec = {
      id: i,
      status: statuses[Math.floor(rand() * 4)],
      region: regions[Math.floor(rand() * 3)],
      score: Math.floor(rand() * 100),
    };
    if (i % 97 === 0) delete rec.status;
    records.push(rec);
  }
  return records;
}

const records = makeDataset();
const text = records.map((r) => JSON.stringify(r)).join("\n");
const val = (r, f) => (Object.hasOwn(r, f) ? r[f] : null);

test("without indexes explain scans everything", () => {
  const db = new JsonlDatabase(text);
  assert.deepEqual(db.explain({ where: { status: "active" } }), {
    index: null,
    scanned: 1000,
  });
});

test("equality on an indexed field narrows scanned to the exact bucket", () => {
  const db = new JsonlDatabase(text);
  db.createIndex("status");
  const bucket = records.filter((r) => val(r, "status") === "active").length;
  assert.deepEqual(db.explain({ where: { status: "active" } }), {
    index: "status",
    scanned: bucket,
  });
  assert.deepEqual(
    db.find({ where: { status: "active" } }),
    records.filter((r) => val(r, "status") === "active"),
  );
});

test("null bucket covers records missing the field", () => {
  const db = new JsonlDatabase(text);
  db.createIndex("status");
  assert.deepEqual(db.explain({ where: { status: null } }), {
    index: "status",
    scanned: 11,
  });
});

test("range conditions use the index with exact window counts", () => {
  const db = new JsonlDatabase(text);
  db.createIndex("score");
  const high = records.filter((r) => r.score >= 90).length;
  assert.deepEqual(db.explain({ where: { score: { $gte: 90 } } }), {
    index: "score",
    scanned: high,
  });
  const window = records.filter((r) => r.score >= 20 && r.score < 25).length;
  assert.deepEqual(db.explain({ where: { score: { $gte: 20, $lt: 25 } } }), {
    index: "score",
    scanned: window,
  });
  assert.deepEqual(
    db.find({ where: { score: { $gte: 20, $lt: 25 } } }),
    records.filter((r) => r.score >= 20 && r.score < 25),
  );
});

test("$in narrows to the union of buckets", () => {
  const db = new JsonlDatabase(text);
  db.createIndex("status");
  const union = records.filter((r) =>
    ["banned", "new"].includes(val(r, "status")),
  ).length;
  assert.deepEqual(db.explain({ where: { status: { $in: ["banned", "new"] } } }), {
    index: "status",
    scanned: union,
  });
});

test("$ne alone cannot use the index", () => {
  const db = new JsonlDatabase(text);
  db.createIndex("status");
  assert.deepEqual(db.explain({ where: { status: { $ne: "active" } } }), {
    index: null,
    scanned: 1000,
  });
});

test("planner takes the first usable indexed field in where order", () => {
  const db = new JsonlDatabase(text);
  db.createIndex("status");
  db.createIndex("region");
  const plan = db.explain({ where: { region: "eu", status: "active" } });
  assert.equal(plan.index, "region");

  const skipUnusable = db.explain({
    where: { status: { $ne: "x" }, region: "eu" },
  });
  assert.equal(skipUnusable.index, "region");

  const skipUnindexed = db.explain({ where: { score: 10, status: "active" } });
  assert.equal(skipUnindexed.index, "status");
});

test("index narrows candidates while other conditions still apply", () => {
  const db = new JsonlDatabase(text);
  db.createIndex("score");
  const scanned = records.filter((r) => r.score >= 90).length;
  const plan = db.explain({ where: { score: { $gte: 90 }, status: "active" } });
  assert.deepEqual(plan, { index: "score", scanned });
  assert.deepEqual(
    db.find({ where: { score: { $gte: 90 }, status: "active" } }),
    records.filter((r) => r.score >= 90 && val(r, "status") === "active"),
  );
});

test("indexed and unindexed results agree, and createIndex is idempotent", () => {
  const plain = new JsonlDatabase(text);
  const indexed = new JsonlDatabase(text);
  indexed.createIndex("status");
  indexed.createIndex("status");
  const query = {
    where: { status: { $in: ["active", "idle"] }, score: { $lt: 30 } },
    orderBy: ["score", "desc"],
    limit: 20,
  };
  assert.deepEqual(indexed.find(query), plain.find(query));
});

test("bad input lines report their line number", () => {
  assert.throws(() => new JsonlDatabase('{"a":1}\nnot json'), /line 2/);
  assert.throws(() => new JsonlDatabase('{"a":1}\n\n[1,2]'), /line 3/);
  assert.throws(() => new JsonlDatabase('{"a":1}\n"scalar"'), /line 2/);
});

test("query validation errors", () => {
  const db = new JsonlDatabase(text);
  assert.throws(() => db.find({ where: { score: { $abs: 1 } } }), /\$abs/);
  assert.throws(() => db.find({ orderBy: ["score", "sideways"] }), /sideways/);
  assert.throws(() => db.find({ limit: -1 }), RangeError);
  assert.throws(() => db.find({ offset: 1.5 }), RangeError);
});

test("cross-type ordering: null < numbers < strings < booleans", () => {
  const db = new JsonlDatabase(
    [
      '{"id":0,"v":true}',
      '{"id":1,"v":"apple"}',
      '{"id":2,"v":10}',
      '{"id":3}',
      '{"id":4,"v":false}',
      '{"id":5,"v":2}',
      '{"id":6,"v":"banana"}',
    ].join("\n"),
  );
  const sorted = db.find({ orderBy: ["v", "asc"], select: ["id"] });
  assert.deepEqual(
    sorted.map((r) => r.id),
    [3, 5, 2, 1, 6, 4, 0],
  );
});

test("fromFile reads a JSONL file", async () => {
  const path = "fromfile-fixture.jsonl";
  await writeFile(path, '{"id":1}\n{"id":2}\n\n{"id":3}\n');
  try {
    const db = await JsonlDatabase.fromFile(path);
    assert.equal(db.count(), 3);
    assert.deepEqual(db.find({ where: { id: { $gte: 2 } } }), [
      { id: 2 },
      { id: 3 },
    ]);
  } finally {
    await rm(path, { force: true });
  }
});
