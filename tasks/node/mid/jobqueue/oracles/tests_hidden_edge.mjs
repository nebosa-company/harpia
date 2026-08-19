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

test("backoff doubles per attempt and the last error surfaces", async () => {
  const sched = fakeScheduler();
  const q = createQueue({ maxRetries: 3, baseDelayMs: 100, schedule: sched.schedule });
  const attempts = [];
  const p = q.push(async (attempt) => {
    attempts.push(attempt);
    throw new Error(`fail ${attempt}`);
  });
  p.catch(() => {}); // observed later
  await settle();
  sched.flush();
  await settle();
  sched.flush();
  await settle();
  sched.flush();
  await settle();
  assert.deepEqual(sched.allDelays, [100, 200, 400]);
  assert.deepEqual(attempts, [1, 2, 3, 4]);
  await assert.rejects(p, /fail 4/);
});

test("a retrying job goes to the back of the queue", async () => {
  const sched = fakeScheduler();
  const q = createQueue({ concurrency: 1, maxRetries: 1, baseDelayMs: 0, schedule: sched.schedule });
  const order = [];
  const pa = q.push(async (attempt) => {
    order.push(`A${attempt}`);
    if (attempt === 1) throw new Error("A first try");
    return "A ok";
  });
  const pb = q.push(async () => {
    order.push("B");
    return "B ok";
  });
  assert.equal(await pb, "B ok", "B runs while A waits for its retry");
  sched.flush();
  await settle();
  assert.equal(await pa, "A ok");
  assert.deepEqual(order, ["A1", "B", "A2"]);
});

test("a job waiting for retry does not hold a slot", async () => {
  const sched = fakeScheduler();
  const q = createQueue({ concurrency: 1, maxRetries: 1, baseDelayMs: 1000, schedule: sched.schedule });
  const pa = q.push(async (attempt) => {
    if (attempt === 1) throw new Error("later");
    return "eventually";
  });
  pa.catch(() => {});
  await settle();
  assert.equal(q.active(), 0, "delay-pending job is not active");
  assert.equal(q.size(), 0, "delay-pending job is not waiting");
  const pb = q.push(async () => "B");
  assert.equal(await pb, "B");
  sched.flush();
  await settle();
  assert.equal(await pa, "eventually");
});

test("onIdle waits for retry-pending work", async () => {
  const sched = fakeScheduler();
  const q = createQueue({ maxRetries: 1, baseDelayMs: 10, schedule: sched.schedule });
  const p = q.push(async (attempt) => {
    if (attempt === 1) throw new Error("again");
    return "ok";
  });
  p.catch(() => {});
  let idle = false;
  const idlePromise = q.onIdle().then(() => {
    idle = true;
  });
  await settle();
  assert.equal(idle, false, "retry still pending: not idle");
  sched.flush();
  await settle();
  await idlePromise;
  assert.equal(idle, true);
  assert.equal(await p, "ok");
});

test("onIdle resolves immediately on a fresh queue", async () => {
  const q = createQueue();
  await q.onIdle();
  assert.ok(true);
});

test("attempt numbers are passed to the job", async () => {
  const sched = fakeScheduler();
  const q = createQueue({ maxRetries: 2, baseDelayMs: 5, schedule: sched.schedule });
  const seen = [];
  const p = q.push((attempt) => {
    seen.push(attempt);
    if (attempt < 3) throw new Error("not yet");
    return attempt;
  });
  p.catch(() => {});
  await settle();
  sched.flush();
  await settle();
  sched.flush();
  await settle();
  assert.equal(await p, 3);
  assert.deepEqual(seen, [1, 2, 3]);
});
