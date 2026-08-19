import test from "node:test";
import assert from "node:assert/strict";
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

test("parses and keeps record order", () => {
  const db = new JsonlDatabase(text);
  assert.equal(db.count(), 1000);
  const all = db.find({});
  assert.equal(all.length, 1000);
  assert.deepEqual(
    all.slice(0, 5).map((r) => r.id),
    [0, 1, 2, 3, 4],
  );
});

test("scalar equality matches strictly", () => {
  const db = new JsonlDatabase(text);
  const got = db.find({ where: { status: "active" } });
  const want = records.filter((r) => val(r, "status") === "active");
  assert.deepEqual(got, want);
  assert.ok(want.length > 100, "dataset sanity");
});

test("operator conditions AND together across fields", () => {
  const db = new JsonlDatabase(text);
  const got = db.find({ where: { score: { $gte: 50, $lt: 60 }, region: "eu" } });
  const want = records.filter(
    (r) => r.score >= 50 && r.score < 60 && r.region === "eu",
  );
  assert.deepEqual(got, want);
  assert.ok(want.length > 0, "dataset sanity");
});

test("$in and $ne", () => {
  const db = new JsonlDatabase(text);
  const inGot = db.find({ where: { status: { $in: ["banned", "idle"] } } });
  const inWant = records.filter((r) =>
    ["banned", "idle"].includes(val(r, "status")),
  );
  assert.deepEqual(inGot, inWant);

  const neGot = db.find({ where: { region: { $ne: "us" } } });
  const neWant = records.filter((r) => r.region !== "us");
  assert.deepEqual(neGot, neWant);
});

test("missing fields compare as null", () => {
  const db = new JsonlDatabase(text);
  const got = db.find({ where: { status: null } });
  const want = records.filter((r) => !Object.hasOwn(r, "status"));
  assert.deepEqual(got, want);
  assert.equal(got.length, 11);
});

test("ordering operators never match null or mixed types", () => {
  const db = new JsonlDatabase(text);
  const got = db.find({ where: { status: { $gt: "" } } });
  const want = records.filter((r) => typeof val(r, "status") === "string");
  assert.deepEqual(got, want, "missing-status records must not match $gt");
});

test("orderBy sorts and is stable", () => {
  const db = new JsonlDatabase(text);
  const asc = db.find({ orderBy: ["score", "asc"] });
  for (let i = 1; i < asc.length; i++) {
    assert.ok(
      asc[i - 1].score < asc[i].score ||
        (asc[i - 1].score === asc[i].score && asc[i - 1].id < asc[i].id),
      `stable ascending order violated at ${i}`,
    );
  }
  const desc = db.find({ orderBy: ["score", "desc"] });
  for (let i = 1; i < desc.length; i++) {
    assert.ok(
      desc[i - 1].score > desc[i].score ||
        (desc[i - 1].score === desc[i].score && desc[i - 1].id < desc[i].id),
      `stable descending order violated at ${i}`,
    );
  }
});

test("offset and limit apply after ordering", () => {
  const db = new JsonlDatabase(text);
  const full = db.find({ orderBy: ["score", "asc"] });
  const page = db.find({ orderBy: ["score", "asc"], offset: 10, limit: 5 });
  assert.deepEqual(page, full.slice(10, 15));
  const tail = db.find({ orderBy: ["score", "asc"], offset: 998 });
  assert.deepEqual(tail, full.slice(998));
});

test("select projects fresh objects with only the named fields", () => {
  const db = new JsonlDatabase(text);
  const rows = db.find({
    where: { status: null },
    select: ["id", "status", "score"],
  });
  for (const row of rows) {
    assert.deepEqual(Object.keys(row).sort(), ["id", "score"]);
  }
  const normal = db.find({ where: { id: 1 }, select: ["id", "region"] });
  assert.deepEqual(normal, [{ id: 1, region: records[1].region }]);
});
