import test from "node:test";
import assert from "node:assert/strict";
import { EventStore } from "./eventstore.mjs";

test("append assigns global seq and per-stream versions", () => {
  const store = new EventStore();
  const e1 = store.append("acct-1", "opened", { by: "ada" });
  const e2 = store.append("acct-2", "opened", { by: "alan" });
  const e3 = store.append("acct-1", "credited", { amount: 50 });
  assert.deepEqual(e1, {
    seq: 1,
    streamId: "acct-1",
    version: 1,
    type: "opened",
    data: { by: "ada" },
  });
  assert.equal(e2.seq, 2);
  assert.equal(e2.version, 1);
  assert.deepEqual(e3, {
    seq: 3,
    streamId: "acct-1",
    version: 2,
    type: "credited",
    data: { amount: 50 },
  });
});

test("readStream returns one stream in version order", () => {
  const store = new EventStore();
  store.append("a", "t1", {});
  store.append("b", "t2", {});
  store.append("a", "t3", {});
  const a = store.readStream("a");
  assert.deepEqual(
    a.map((e) => [e.version, e.type]),
    [
      [1, "t1"],
      [2, "t3"],
    ],
  );
  assert.deepEqual(store.readStream("nope"), []);
});

test("readAll in seq order with fromSeq", () => {
  const store = new EventStore();
  store.append("a", "t1", {});
  store.append("b", "t2", {});
  store.append("a", "t3", {});
  assert.deepEqual(
    store.readAll().map((e) => e.seq),
    [1, 2, 3],
  );
  assert.deepEqual(
    store.readAll({ fromSeq: 2 }).map((e) => e.seq),
    [2, 3],
  );
});

test("projection registered first follows appends", () => {
  const store = new EventStore();
  store.registerProjection("balances", {
    init: () => ({}),
    apply: (state, event) => {
      const next = { ...state };
      const delta = event.type === "credited" ? event.data.amount : -event.data.amount;
      next[event.streamId] = (next[event.streamId] ?? 0) + delta;
      return next;
    },
  });
  store.append("acct-1", "credited", { amount: 100 });
  store.append("acct-1", "debited", { amount: 30 });
  store.append("acct-2", "credited", { amount: 5 });
  assert.deepEqual(store.getProjection("balances"), { "acct-1": 70, "acct-2": 5 });
});

test("projection registered late replays history identically", () => {
  const build = () => {
    const store = new EventStore();
    const handlers = {
      init: () => ({ count: 0, lastSeq: 0 }),
      apply: (s, e) => ({ count: s.count + 1, lastSeq: e.seq }),
    };
    return { store, handlers };
  };
  const early = build();
  early.store.registerProjection("p", early.handlers);
  early.store.append("s", "x", {});
  early.store.append("s", "y", {});

  const late = build();
  late.store.append("s", "x", {});
  late.store.append("s", "y", {});
  late.store.registerProjection("p", late.handlers);

  assert.deepEqual(early.store.getProjection("p"), late.store.getProjection("p"));
  assert.deepEqual(late.store.getProjection("p"), { count: 2, lastSeq: 2 });
});
