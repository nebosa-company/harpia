import test from "node:test";
import assert from "node:assert/strict";
import { createQueue } from "./jobqueue.mjs";

async function settle() {
  for (let i = 0; i < 20; i++) {
    await new Promise((r) => setImmediate(r));
  }
}

function fakeScheduler() {
  const pending = [];
  const allDelays = [];
  return {
    schedule: (fn, delay) => {
      pending.push(fn);
      allDelays.push(delay);
    },
    flush: () => {
      const fns = pending.splice(0);
      for (const fn of fns) fn();
    },
    pendingCount: () => pending.length,
    allDelays,
  };
}

function deferred() {
  let resolve, reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

test("push resolves with the job's value", async () => {
  const q = createQueue();
  assert.equal(await q.push(async () => 42), 42);
  assert.equal(await q.push(() => "sync value"), "sync value");
});

test("jobs run in FIFO order at concurrency 1", async () => {
  const q = createQueue({ concurrency: 1 });
  const order = [];
  const jobs = [1, 2, 3].map((n) =>
    q.push(async () => {
      order.push(n);
      await new Promise((r) => setImmediate(r));
      return n;
    }),
  );
  assert.deepEqual(await Promise.all(jobs), [1, 2, 3]);
  assert.deepEqual(order, [1, 2, 3]);
});

test("concurrency is capped and slots refill", async () => {
  const q = createQueue({ concurrency: 2 });
  const gates = [deferred(), deferred(), deferred(), deferred()];
  let current = 0;
  let peak = 0;
  const jobs = gates.map((gate) =>
    q.push(async () => {
      current += 1;
      peak = Math.max(peak, current);
      await gate.promise;
      current -= 1;
      return "done";
    }),
  );
  await settle();
  assert.equal(q.active(), 2, "two jobs running");
  assert.equal(q.size(), 2, "two jobs waiting");
  gates[0].resolve();
  await settle();
  assert.equal(q.active(), 2, "slot refilled from the queue");
  assert.equal(q.size(), 1);
  gates[1].resolve();
  gates[2].resolve();
  gates[3].resolve();
  await Promise.all(jobs);
  assert.equal(peak, 2, "never more than concurrency jobs at once");
  assert.equal(q.active(), 0);
  assert.equal(q.size(), 0);
});

test("rejects after the only attempt when maxRetries is 0", async () => {
  const q = createQueue();
  const attempts = [];
  await assert.rejects(
    q.push(async (attempt) => {
      attempts.push(attempt);
      throw new Error("nope");
    }),
    /nope/,
  );
  assert.deepEqual(attempts, [1]);
});

test("a failed attempt retries through the scheduler and succeeds", async () => {
  const sched = fakeScheduler();
  const q = createQueue({ maxRetries: 2, baseDelayMs: 50, schedule: sched.schedule });
  const attempts = [];
  const p = q.push(async (attempt) => {
    attempts.push(attempt);
    if (attempt === 1) throw new Error("first try fails");
    return "second try wins";
  });
  await settle();
  assert.deepEqual(attempts, [1]);
  assert.equal(sched.pendingCount(), 1, "retry waits on the injected scheduler");
  assert.deepEqual(sched.allDelays, [50]);
  sched.flush();
  await settle();
  assert.equal(await p, "second try wins");
  assert.deepEqual(attempts, [1, 2]);
});
