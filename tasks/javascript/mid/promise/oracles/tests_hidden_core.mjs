import test from "node:test";
import assert from "node:assert/strict";
import { MyPromise } from "./mypromise.mjs";

const flush = () => new Promise((resolve) => setImmediate(resolve));

test("the executor runs synchronously", () => {
  let ran = false;
  new MyPromise(() => {
    ran = true;
  });
  assert.equal(ran, true);
});

test("a non-function executor is a TypeError", () => {
  for (const bad of [undefined, null, 1, "fn", {}]) {
    assert.throws(() => new MyPromise(bad), TypeError, String(bad));
  }
});

test("fulfilment reaches then", async () => {
  const p = new MyPromise((resolve) => resolve(42));
  const seen = [];
  p.then((v) => seen.push(v));
  await flush();
  assert.deepEqual(seen, [42]);
});

test("rejection reaches the second handler and catch", async () => {
  const seen = [];
  new MyPromise((_r, reject) => reject(new Error("boom"))).then(
    () => seen.push("wrong"),
    (e) => seen.push(`then:${e.message}`),
  );
  new MyPromise((_r, reject) => reject(new Error("bang"))).catch((e) => seen.push(`catch:${e.message}`));
  await flush();
  assert.deepEqual(seen, ["then:boom", "catch:bang"]);
});

test("an asynchronously resolved promise still notifies", async () => {
  let later;
  const p = new MyPromise((resolve) => {
    later = resolve;
  });
  const seen = [];
  p.then((v) => seen.push(v));
  await flush();
  assert.deepEqual(seen, []);
  later("late");
  await flush();
  assert.deepEqual(seen, ["late"]);
});

test("then returns a new MyPromise", () => {
  const p = MyPromise.resolve(1);
  const q = p.then(() => 2);
  assert.ok(q instanceof MyPromise);
  assert.notEqual(q, p);
});

test("handler return values chain", async () => {
  const seen = [];
  MyPromise.resolve(1)
    .then((v) => v + 1)
    .then((v) => v * 10)
    .then((v) => seen.push(v));
  await flush();
  assert.deepEqual(seen, [20]);
});

test("a throwing handler rejects the chained promise", async () => {
  const seen = [];
  MyPromise.resolve(1)
    .then(() => {
      throw new Error("thrown");
    })
    .then(
      () => seen.push("wrong"),
      (e) => seen.push(e.message),
    );
  await flush();
  assert.deepEqual(seen, ["thrown"]);
});

test("catch recovers and the chain continues", async () => {
  const seen = [];
  MyPromise.reject(new Error("x"))
    .catch(() => "recovered")
    .then((v) => seen.push(v));
  await flush();
  assert.deepEqual(seen, ["recovered"]);
});

test("returning a MyPromise from a handler adopts it", async () => {
  const seen = [];
  MyPromise.resolve(1)
    .then(() => new MyPromise((resolve) => queueMicrotask(() => resolve("inner"))))
    .then((v) => seen.push(v));
  await flush();
  assert.deepEqual(seen, ["inner"]);
});

test("returning a plain thenable from a handler adopts it", async () => {
  const seen = [];
  MyPromise.resolve(1)
    .then(() => ({
      then(resolve) {
        resolve("thenable");
      },
    }))
    .then((v) => seen.push(v));
  await flush();
  assert.deepEqual(seen, ["thenable"]);
});

test("resolving with a native promise adopts it", async () => {
  const seen = [];
  new MyPromise((resolve) => resolve(Promise.resolve("native"))).then((v) => seen.push(v));
  await flush();
  assert.deepEqual(seen, ["native"]);
});

test("a rejecting thenable rejects the promise", async () => {
  const seen = [];
  new MyPromise((resolve) =>
    resolve({
      then(_res, rej) {
        rej(new Error("thenable failed"));
      },
    }),
  ).catch((e) => seen.push(e.message));
  await flush();
  assert.deepEqual(seen, ["thenable failed"]);
});

test("instances are awaitable", async () => {
  assert.equal(await MyPromise.resolve("awaited"), "awaited");
  await assert.rejects(async () => {
    await MyPromise.reject(new RangeError("nope"));
  }, RangeError);
});

test("several then calls on one promise all fire in order", async () => {
  const p = MyPromise.resolve("v");
  const seen = [];
  p.then((v) => seen.push(`1:${v}`));
  p.then((v) => seen.push(`2:${v}`));
  p.then((v) => seen.push(`3:${v}`));
  await flush();
  assert.deepEqual(seen, ["1:v", "2:v", "3:v"]);
});

test("a pending promise notifies every registered handler", async () => {
  let later;
  const p = new MyPromise((resolve) => {
    later = resolve;
  });
  const seen = [];
  p.then((v) => seen.push(`a:${v}`));
  p.then((v) => seen.push(`b:${v}`));
  later(7);
  await flush();
  assert.deepEqual(seen, ["a:7", "b:7"]);
});

test("static resolve and reject", async () => {
  const p = MyPromise.resolve("v");
  assert.ok(p instanceof MyPromise);
  assert.equal(await p, "v");
  await assert.rejects(async () => {
    await MyPromise.reject(new Error("r"));
  }, /r/);
});

test("all fulfils with the values in input order", async () => {
  const values = await MyPromise.all([
    MyPromise.resolve(1),
    2,
    new MyPromise((resolve) => queueMicrotask(() => resolve(3))),
    Promise.resolve(4),
  ]);
  assert.deepEqual(values, [1, 2, 3, 4]);
});

test("all rejects when an entry rejects", async () => {
  await assert.rejects(
    async () => await MyPromise.all([MyPromise.resolve(1), MyPromise.reject(new Error("bad")), 3]),
    /bad/,
  );
});

test("all of an empty list fulfils with an empty array", async () => {
  assert.deepEqual(await MyPromise.all([]), []);
});
