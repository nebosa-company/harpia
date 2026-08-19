import test from "node:test";
import assert from "node:assert/strict";
import { MyPromise } from "./mypromise.mjs";

const flush = () => new Promise((resolve) => setImmediate(resolve));

test("handlers never run synchronously", async () => {
  const log = [];
  MyPromise.resolve(1).then(() => log.push("handler"));
  log.push("after-then");
  assert.deepEqual(log, ["after-then"]);
  await flush();
  assert.deepEqual(log, ["after-then", "handler"]);
});

test("microtask interleaving matches the native promise", async () => {
  const mine = [];
  MyPromise.resolve()
    .then(() => mine.push("a1"))
    .then(() => mine.push("a2"))
    .then(() => mine.push("a3"));
  MyPromise.resolve()
    .then(() => mine.push("b1"))
    .then(() => mine.push("b2"))
    .then(() => mine.push("b3"));
  await flush();

  const native = [];
  Promise.resolve()
    .then(() => native.push("a1"))
    .then(() => native.push("a2"))
    .then(() => native.push("a3"));
  Promise.resolve()
    .then(() => native.push("b1"))
    .then(() => native.push("b2"))
    .then(() => native.push("b3"));
  await flush();

  assert.deepEqual(mine, ["a1", "b1", "a2", "b2", "a3", "b3"]);
  assert.deepEqual(mine, native);
});

test("a promise settles once: later resolve and reject calls are ignored", async () => {
  const seen = [];
  new MyPromise((resolve, reject) => {
    resolve("first");
    resolve("second");
    reject(new Error("too late"));
  }).then(
    (v) => seen.push(v),
    (e) => seen.push(`rejected:${e.message}`),
  );
  await flush();
  assert.deepEqual(seen, ["first"]);
});

test("a rejection cannot be overturned by a later resolve", async () => {
  const seen = [];
  new MyPromise((resolve, reject) => {
    reject(new Error("first"));
    resolve("ignored");
  }).then(
    (v) => seen.push(`ok:${v}`),
    (e) => seen.push(`err:${e.message}`),
  );
  await flush();
  assert.deepEqual(seen, ["err:first"]);
});

test("a throwing executor rejects the promise", async () => {
  const seen = [];
  new MyPromise(() => {
    throw new Error("executor failed");
  }).catch((e) => seen.push(e.message));
  await flush();
  assert.deepEqual(seen, ["executor failed"]);
});

test("a throw after resolve is ignored", async () => {
  const seen = [];
  new MyPromise((resolve) => {
    resolve("ok");
    throw new Error("ignored");
  }).then(
    (v) => seen.push(v),
    (e) => seen.push(`err:${e.message}`),
  );
  await flush();
  assert.deepEqual(seen, ["ok"]);
});

test("resolving a promise with itself rejects with a TypeError", async () => {
  let resolveSelf;
  const p = new MyPromise((resolve) => {
    resolveSelf = resolve;
  });
  resolveSelf(p);
  const seen = [];
  p.catch((e) => seen.push(e));
  await flush();
  assert.equal(seen.length, 1);
  assert.ok(seen[0] instanceof TypeError);
});

test("a thenable that reports twice is honoured only once", async () => {
  const seen = [];
  new MyPromise((resolve) =>
    resolve({
      then(res, rej) {
        res("first");
        res("second");
        rej(new Error("late"));
      },
    }),
  ).then(
    (v) => seen.push(v),
    (e) => seen.push(`err:${e.message}`),
  );
  await flush();
  assert.deepEqual(seen, ["first"]);
});

test("a thenable whose then throws rejects the promise", async () => {
  const seen = [];
  new MyPromise((resolve) =>
    resolve({
      then() {
        throw new Error("then exploded");
      },
    }),
  ).catch((e) => seen.push(e.message));
  await flush();
  assert.deepEqual(seen, ["then exploded"]);
});

test("a then getter that throws rejects the promise", async () => {
  const hostile = {
    get then() {
      throw new Error("getter exploded");
    },
  };
  const seen = [];
  new MyPromise((resolve) => resolve(hostile)).catch((e) => seen.push(e.message));
  await flush();
  assert.deepEqual(seen, ["getter exploded"]);
});

test("nested thenables are unwrapped all the way down", async () => {
  const inner = { then: (res) => res("deep") };
  const middle = { then: (res) => res(inner) };
  const outer = { then: (res) => res(middle) };
  const seen = [];
  new MyPromise((resolve) => resolve(outer)).then((v) => seen.push(v));
  await flush();
  assert.deepEqual(seen, ["deep"]);
});

test("non-function handlers pass the value or reason through", async () => {
  const seen = [];
  MyPromise.resolve("value")
    .then(null)
    .then(undefined)
    .then("not a function")
    .then((v) => seen.push(`ok:${v}`));
  MyPromise.reject(new Error("reason"))
    .then((v) => seen.push(`wrong:${v}`))
    .catch((e) => seen.push(`err:${e.message}`));
  await flush();
  assert.deepEqual(seen.sort(), ["err:reason", "ok:value"]);
});

test("MyPromise.resolve passes an existing MyPromise straight through", () => {
  const p = MyPromise.resolve(1);
  assert.equal(MyPromise.resolve(p), p);
  const q = new MyPromise(() => {});
  assert.equal(MyPromise.resolve(q), q);
});

test("MyPromise.reject does not adopt a promise reason", async () => {
  const inner = MyPromise.resolve("inner");
  const seen = [];
  MyPromise.reject(inner).catch((r) => seen.push(r));
  await flush();
  assert.deepEqual(seen, [inner]);
});

test("finally passes a value through and waits for its callback", async () => {
  const log = [];
  const value = await MyPromise.resolve("kept").finally(() => {
    log.push("finally");
    return new MyPromise((resolve) =>
      queueMicrotask(() => {
        log.push("finally-done");
        resolve("discarded");
      }),
    );
  });
  assert.equal(value, "kept");
  assert.deepEqual(log, ["finally", "finally-done"]);
});

test("finally passes a rejection through", async () => {
  let ran = false;
  await assert.rejects(
    async () =>
      await MyPromise.reject(new Error("still failing")).finally(() => {
        ran = true;
      }),
    /still failing/,
  );
  assert.equal(ran, true);
});

test("a throwing finally callback replaces the outcome", async () => {
  await assert.rejects(
    async () =>
      await MyPromise.resolve("value").finally(() => {
        throw new Error("finally failed");
      }),
    /finally failed/,
  );
});

test("race settles like the first entry to settle", async () => {
  const slow = new MyPromise((resolve) => setImmediate(() => resolve("slow")));
  const fast = MyPromise.resolve("fast");
  assert.equal(await MyPromise.race([slow, fast]), "fast");
  await assert.rejects(
    async () => await MyPromise.race([MyPromise.reject(new Error("first")), MyPromise.resolve("v")]),
    /first/,
  );
});

test("all keeps order even when later entries settle first", async () => {
  const slow = new MyPromise((resolve) => setImmediate(() => resolve("slow")));
  const quick = MyPromise.resolve("quick");
  assert.deepEqual(await MyPromise.all([slow, quick]), ["slow", "quick"]);
});

test("all accepts any iterable", async () => {
  function* gen() {
    yield 1;
    yield MyPromise.resolve(2);
  }
  assert.deepEqual(await MyPromise.all(gen()), [1, 2]);
  assert.deepEqual(await MyPromise.all(new Set([1, 2])), [1, 2]);
});

test("handlers attached long after settlement still run", async () => {
  const p = MyPromise.resolve("late");
  await flush();
  await flush();
  const seen = [];
  p.then((v) => seen.push(v));
  await flush();
  assert.deepEqual(seen, ["late"]);
});
