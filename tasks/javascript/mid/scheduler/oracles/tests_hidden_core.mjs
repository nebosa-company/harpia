import test from "node:test";
import assert from "node:assert/strict";
import { createScheduler, sleep, send, receive, join, fork } from "./scheduler.mjs";

test("tasks are interleaved round by round in spawn order", () => {
  const s = createScheduler();
  const log = [];
  function* worker(name, steps) {
    for (let i = 0; i < steps; i++) {
      log.push(`${name}${i}`);
      yield;
    }
    return `${name}-done`;
  }
  assert.equal(s.spawn(worker, "a", 3), 1);
  assert.equal(s.spawn(worker, "b", 2), 2);
  const report = s.run();
  assert.deepEqual(log, ["a0", "b0", "a1", "b1", "a2"]);
  assert.equal(report.rounds, 4);
  assert.deepEqual(
    report.tasks.map((t) => [t.id, t.status, t.value]),
    [
      [1, "done", "a-done"],
      [2, "done", "b-done"],
    ],
  );
});

test("the report shape is exact", () => {
  const s = createScheduler();
  function* t() {
    return 5;
  }
  s.spawn(t);
  const report = s.run();
  assert.deepEqual(Object.keys(report).sort(), ["rounds", "tasks"]);
  assert.deepEqual(report.tasks, [{ id: 1, status: "done", value: 5, error: undefined }]);
});

test("a task that never yields finishes in one round", () => {
  const s = createScheduler();
  function* immediate() {
    return "immediate";
  }
  s.spawn(immediate);
  const report = s.run();
  assert.equal(report.rounds, 1);
  assert.equal(report.tasks[0].value, "immediate");
});

test("running with no tasks does nothing", () => {
  const s = createScheduler();
  const report = s.run();
  assert.equal(report.rounds, 0);
  assert.deepEqual(report.tasks, []);
});

test("a bare yield evaluates to undefined", () => {
  const s = createScheduler();
  function* t() {
    const v = yield;
    return v === undefined ? "undefined" : `got ${v}`;
  }
  s.spawn(t);
  assert.equal(s.run().tasks[0].value, "undefined");
});

test("send and receive move values between tasks", () => {
  const s = createScheduler();
  function* producer() {
    yield send("q", 1);
    yield send("q", 2);
    return "sent";
  }
  function* consumer() {
    const a = yield receive("q");
    const b = yield receive("q");
    return a + b;
  }
  s.spawn(producer);
  s.spawn(consumer);
  const report = s.run();
  assert.equal(report.rounds, 3);
  assert.deepEqual(
    report.tasks.map((t) => t.value),
    ["sent", 3],
  );
  assert.deepEqual(s.queued("q"), []);
});

test("a receiver blocks until a value arrives", () => {
  const s = createScheduler();
  const log = [];
  function* late() {
    yield sleep(2);
    log.push("sending");
    yield send("q", "payload");
  }
  function* waiting() {
    log.push("waiting");
    const v = yield receive("q");
    log.push(`received ${v}`);
  }
  s.spawn(late);
  s.spawn(waiting);
  const report = s.run();
  assert.deepEqual(log, ["waiting", "sending", "received payload"]);
  assert.equal(report.tasks.every((t) => t.status === "done"), true);
});

test("join resumes with the other task's return value", () => {
  const s = createScheduler();
  function* child() {
    yield;
    return 42;
  }
  function* parent(id) {
    const v = yield join(id);
    return v * 2;
  }
  const childId = s.spawn(child);
  s.spawn(parent, childId);
  const report = s.run();
  assert.equal(report.rounds, 2);
  assert.deepEqual(
    report.tasks.map((t) => t.value),
    [42, 84],
  );
});

test("fork starts a task that runs from the next round", () => {
  const s = createScheduler();
  const log = [];
  function* child() {
    log.push("child");
    return "child-result";
  }
  function* main() {
    log.push("main-1");
    const id = yield fork(child);
    log.push(`forked-${id}`);
    return id;
  }
  s.spawn(main);
  const report = s.run();
  assert.deepEqual(log, ["main-1", "forked-2", "child"]);
  assert.equal(report.rounds, 2);
  assert.equal(report.tasks.length, 2);
  assert.equal(report.tasks[0].value, 2);
  assert.equal(report.tasks[1].value, "child-result");
});

test("a failing task is recorded and the others carry on", () => {
  const s = createScheduler();
  const log = [];
  function* bad() {
    yield;
    throw new TypeError("bad task");
  }
  function* good() {
    log.push("g1");
    yield;
    log.push("g2");
    return "ok";
  }
  s.spawn(bad);
  s.spawn(good);
  const report = s.run();
  assert.deepEqual(log, ["g1", "g2"]);
  assert.equal(report.tasks[0].status, "failed");
  assert.ok(report.tasks[0].error instanceof TypeError);
  assert.equal(report.tasks[0].error.message, "bad task");
  assert.equal(report.tasks[0].value, undefined);
  assert.deepEqual(report.tasks[1], { id: 2, status: "done", value: "ok", error: undefined });
});

test("sleep parks a task for the given number of rounds", () => {
  const s = createScheduler();
  const log = [];
  function* sleeper() {
    log.push("start");
    yield sleep(2);
    log.push("woke");
  }
  function* ticker() {
    for (let i = 0; i < 4; i++) {
      log.push(`t${i}`);
      yield;
    }
  }
  s.spawn(sleeper);
  s.spawn(ticker);
  const report = s.run();
  assert.deepEqual(log, ["start", "t0", "t1", "t2", "woke", "t3"]);
  assert.equal(report.rounds, 5);
});

test("arguments are passed to the generator function", () => {
  const s = createScheduler();
  function* adder(a, b) {
    yield;
    return a + b;
  }
  s.spawn(adder, 2, 3);
  assert.equal(s.run().tasks[0].value, 5);
});

test("a fresh scheduler has its own ids and channels", () => {
  const a = createScheduler();
  const b = createScheduler();
  function* t() {
    yield send("q", "x");
  }
  assert.equal(a.spawn(t), 1);
  assert.equal(b.spawn(t), 1);
  a.run();
  assert.deepEqual(a.queued("q"), ["x"]);
  assert.deepEqual(b.queued("q"), []);
});
