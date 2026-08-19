import test from "node:test";
import assert from "node:assert/strict";
import { EventStore } from "./eventstore.mjs";

test("expectedVersion accepts the current version", () => {
  const store = new EventStore();
  store.append("s", "a", {}, { expectedVersion: 0 });
  store.append("s", "b", {}, { expectedVersion: 1 });
  const e = store.append("s", "c", {}, { expectedVersion: 2 });
  assert.equal(e.version, 3);
});

test("expectedVersion mismatch throws CONCURRENCY and appends nothing", () => {
  const store = new EventStore();
  store.append("s", "a", {});
  assert.throws(
    () => store.append("s", "b", {}, { expectedVersion: 0 }),
    (err) => err instanceof Error && err.code === "CONCURRENCY",
  );
  assert.throws(
    () => store.append("fresh", "b", {}, { expectedVersion: 3 }),
    (err) => err.code === "CONCURRENCY",
  );
  assert.equal(store.readStream("s").length, 1);
  assert.deepEqual(store.readStream("fresh"), []);
  assert.equal(store.readAll().length, 1);
  const next = store.append("s", "b", {});
  assert.equal(next.seq, 2, "failed appends must not burn seq numbers");
});

test("failed appends do not reach projections", () => {
  const store = new EventStore();
  store.registerProjection("count", {
    init: () => 0,
    apply: (n) => n + 1,
  });
  store.append("s", "a", {});
  try {
    store.append("s", "b", {}, { expectedVersion: 99 });
  } catch {
    // expected
  }
  assert.equal(store.getProjection("count"), 1);
});

test("duplicate projection names are rejected", () => {
  const store = new EventStore();
  store.registerProjection("p", { init: () => 0, apply: (n) => n });
  assert.throws(
    () => store.registerProjection("p", { init: () => 0, apply: (n) => n }),
    (err) => err.code === "DUPLICATE_PROJECTION",
  );
});

test("unknown projection name is rejected", () => {
  const store = new EventStore();
  assert.throws(
    () => store.getProjection("ghost"),
    (err) => err.code === "UNKNOWN_PROJECTION",
  );
});

test("multiple projections evolve independently", () => {
  const store = new EventStore();
  store.registerProjection("types", {
    init: () => [],
    apply: (list, e) => [...list, e.type],
  });
  store.append("s", "one", {});
  store.registerProjection("seqs", {
    init: () => [],
    apply: (list, e) => [...list, e.seq],
  });
  store.append("s", "two", {});
  assert.deepEqual(store.getProjection("types"), ["one", "two"]);
  assert.deepEqual(store.getProjection("seqs"), [1, 2]);
});

test("readAll fromSeq beyond the end is empty", () => {
  const store = new EventStore();
  store.append("s", "a", {});
  assert.deepEqual(store.readAll({ fromSeq: 5 }), []);
});
