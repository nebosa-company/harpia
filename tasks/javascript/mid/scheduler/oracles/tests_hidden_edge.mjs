import test from "node:test";
import assert from "node:assert/strict";
import { createScheduler, sleep, send, receive, join, fork } from "./scheduler.mjs";

test("sleep(0) behaves like a bare yield", () => {
  const s = createScheduler();
  const log = [];
  function* a() {
    log.push("a1");
    yield sleep(0);
    log.push("a2");
  }
  function* b() {
    log.push("b1");
    yield;
    log.push("b2");
  }
  s.spawn(a);
  s.spawn(b);
  const report = s.run();
  assert.deepEqual(log, ["a1", "b1", "a2", "b2"]);
  assert.equal(report.rounds, 2);
});

test("a task waiting on a channel nobody fills ends up blocked", () => {
  const s = createScheduler();
  function* waiter() {
    yield receive("never");
    return "unreachable";
  }
  s.spawn(waiter);
  const report = s.run();
  assert.deepEqual(report.tasks, [{ id: 1, status: "blocked", value: undefined, error: undefined }]);
  assert.equal(report.rounds, 2);
});

test("a blocked task does not stop a finished one from being reported", () => {
  const s = createScheduler();
  function* waiter() {
    yield receive("never");
  }
  function* worker() {
    return "worked";
  }
  s.spawn(waiter);
  s.spawn(worker);
  const report = s.run();
  assert.deepEqual(
    report.tasks.map((t) => t.status),
    ["blocked", "done"],
  );
});

test("joining a task that will never finish blocks both", () => {
  const s = createScheduler();
  function* stuck() {
    yield receive("never");
  }
  function* joiner(id) {
    yield join(id);
  }
  const id = s.spawn(stuck);
  s.spawn(joiner, id);
  const report = s.run();
  assert.deepEqual(
    report.tasks.map((t) => t.status),
    ["blocked", "blocked"],
  );
});

test("a joined task's error is thrown into the joiner", () => {
  const s = createScheduler();
  function* boom() {
    throw new Error("child failed");
  }
  function* parent(id) {
    try {
      yield join(id);
      return "no error";
    } catch (err) {
      return `caught:${err.message}`;
    }
  }
  const id = s.spawn(boom);
  s.spawn(parent, id);
  const report = s.run();
  assert.equal(report.tasks[0].status, "failed");
  assert.equal(report.tasks[1].value, "caught:child failed");
});

test("joining an unknown id throws a RangeError into the task", () => {
  const s = createScheduler();
  function* t() {
    try {
      yield join(99);
      return "no error";
    } catch (err) {
      return err.constructor.name;
    }
  }
  s.spawn(t);
  assert.equal(s.run().tasks[0].value, "RangeError");
});

test("joining an already finished task resumes with its value", () => {
  const s = createScheduler();
  function* quick() {
    return "q";
  }
  function* late(id) {
    yield sleep(2);
    return yield join(id);
  }
  const id = s.spawn(quick);
  s.spawn(late, id);
  const report = s.run();
  assert.equal(report.tasks[1].value, "q");
  assert.equal(report.rounds, 5);
});

test("channels are FIFO and hand different values to different receivers", () => {
  const s = createScheduler();
  const log = [];
  function* producer() {
    yield send("q", "a");
    yield send("q", "b");
  }
  function* consumer(name) {
    const v = yield receive("q");
    log.push(`${name}:${v}`);
  }
  s.spawn(producer);
  s.spawn(consumer, "c1");
  s.spawn(consumer, "c2");
  s.run();
  assert.deepEqual(log, ["c1:a", "c2:b"]);
});

test("values nobody received stay queued", () => {
  const s = createScheduler();
  function* producer() {
    yield send("q", 1);
    yield send("q", 2);
    yield send("q", 3);
  }
  function* consumer() {
    return yield receive("q");
  }
  s.spawn(producer);
  s.spawn(consumer);
  const report = s.run();
  assert.equal(report.tasks[1].value, 1);
  assert.deepEqual(s.queued("q"), [2, 3]);
  const copy = s.queued("q");
  copy.push(99);
  assert.deepEqual(s.queued("q"), [2, 3], "queued returns a copy");
});

test("channels are independent of each other", () => {
  const s = createScheduler();
  function* t() {
    yield send("left", 1);
    yield send("right", 2);
    const v = yield receive("left");
    return v;
  }
  s.spawn(t);
  const report = s.run();
  assert.equal(report.tasks[0].value, 1);
  assert.deepEqual(s.queued("right"), [2]);
  assert.deepEqual(s.queued("left"), []);
});

test("maxRounds stops a runaway task", () => {
  const s = createScheduler();
  function* forever() {
    for (;;) yield;
  }
  s.spawn(forever);
  assert.throws(() => s.run({ maxRounds: 20 }), /maxRounds/);
});

test("a yielded value that is not an instruction is a bare yield", () => {
  const s = createScheduler();
  function* t() {
    const v = yield "hello";
    const w = yield { not: "an instruction" };
    return [v, w];
  }
  s.spawn(t);
  const report = s.run();
  assert.deepEqual(report.tasks[0].value, [undefined, undefined]);
  assert.equal(report.rounds, 3);
});

test("spawn rejects anything that is not a generator function", () => {
  const s = createScheduler();
  for (const bad of [null, undefined, 42, "gen", {}]) {
    assert.throws(() => s.spawn(bad), TypeError, String(bad));
  }
  assert.throws(() => s.spawn(() => 1), TypeError, "a plain function is not an iterator source");
});

test("the instruction helpers validate their arguments", () => {
  assert.throws(() => sleep(-1), TypeError);
  assert.throws(() => sleep(1.5), TypeError);
  assert.throws(() => sleep("2"), TypeError);
  assert.throws(() => send(5, "v"), TypeError);
  assert.throws(() => receive(null), TypeError);
  assert.throws(() => join("1"), TypeError);
  assert.throws(() => join(0), TypeError);
  assert.throws(() => fork("nope"), TypeError);
});

test("a throw from an instruction helper fails just that task", () => {
  const s = createScheduler();
  function* bad() {
    yield sleep(-1);
  }
  function* good() {
    return "fine";
  }
  s.spawn(bad);
  s.spawn(good);
  const report = s.run();
  assert.equal(report.tasks[0].status, "failed");
  assert.ok(report.tasks[0].error instanceof TypeError);
  assert.equal(report.tasks[1].value, "fine");
});

test("forked tasks may fork further tasks", () => {
  const s = createScheduler();
  const log = [];
  function* leaf(n) {
    log.push(`leaf${n}`);
    return n;
  }
  function* middle() {
    const id = yield fork(leaf, 2);
    const v = yield join(id);
    log.push(`middle-got-${v}`);
    return v;
  }
  function* root() {
    const id = yield fork(middle);
    const v = yield join(id);
    return `root-got-${v}`;
  }
  s.spawn(root);
  const report = s.run();
  assert.equal(report.tasks.length, 3);
  assert.equal(report.tasks[0].value, "root-got-2");
  assert.deepEqual(log, ["leaf2", "middle-got-2"]);
});

test("a chain of sleeps advances the round counter", () => {
  const s = createScheduler();
  function* t() {
    yield sleep(1);
    yield sleep(1);
    return "done";
  }
  s.spawn(t);
  const report = s.run();
  assert.equal(report.tasks[0].value, "done");
  assert.equal(report.rounds, 5);
});
