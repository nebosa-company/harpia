import test from "node:test";
import assert from "node:assert/strict";
import {
  fromIterable,
  map,
  filter,
  take,
  chunk,
  concat,
  zip,
  pipeline,
  toArray,
  channel,
} from "./streams.mjs";

const flush = () => new Promise((resolve) => setImmediate(resolve));

function endless(state = {}) {
  state.produced = 0;
  state.closed = false;
  return (async function* () {
    try {
      for (let i = 0; ; i++) {
        state.produced += 1;
        yield i;
      }
    } finally {
      state.closed = true;
    }
  })();
}

test("nothing is produced before a consumer pulls", async () => {
  const state = {};
  const source = endless(state);
  const stream = map(source, (v) => v);
  assert.equal(state.produced, 0);
  await flush();
  assert.equal(state.produced, 0);
  const it = stream[Symbol.asyncIterator]();
  await it.next();
  assert.equal(state.produced, 1);
  await it.return?.();
});

test("taking three from an endless source pulls exactly three", async () => {
  const state = {};
  let mapped = 0;
  const out = await toArray(
    take(
      map(endless(state), (v) => {
        mapped += 1;
        return v * 2;
      }),
      3,
    ),
  );
  assert.deepEqual(out, [0, 2, 4]);
  assert.equal(mapped, 3);
  assert.equal(state.produced, 3);
  assert.equal(state.closed, true, "take must close the source it stopped reading");
});

test("breaking out of a for await closes every upstream stage", async () => {
  const state = {};
  const seen = [];
  for await (const value of map(filter(endless(state), (v) => v % 2 === 0), (v) => `v${v}`)) {
    seen.push(value);
    if (seen.length === 2) break;
  }
  assert.deepEqual(seen, ["v0", "v2"]);
  await flush();
  assert.equal(state.closed, true);
});

test("take(0) never touches the source", async () => {
  const state = {};
  assert.deepEqual(await toArray(take(endless(state), 0)), []);
  assert.equal(state.produced, 0);
});

test("filter does not read ahead", async () => {
  const state = {};
  let tested = 0;
  const out = await toArray(
    take(
      filter(endless(state), (v) => {
        tested += 1;
        return v % 3 === 0;
      }),
      2,
    ),
  );
  assert.deepEqual(out, [0, 3]);
  assert.equal(tested, 4);
  assert.equal(state.produced, 4);
});

test("a throwing source surfaces in the consumer", async () => {
  async function* bad() {
    yield 1;
    throw new Error("source failed");
  }
  await assert.rejects(toArray(bad()), /source failed/);
  await assert.rejects(toArray(map(bad(), (v) => v)), /source failed/);
});

test("a throwing callback surfaces and closes the source", async () => {
  const state = {};
  await assert.rejects(
    toArray(
      map(endless(state), (v) => {
        if (v === 2) throw new RangeError("mapper failed");
        return v;
      }),
    ),
    RangeError,
  );
  await flush();
  assert.equal(state.closed, true);
});

test("a rejecting async callback surfaces", async () => {
  await assert.rejects(
    toArray(
      filter([1, 2, 3], async (v) => {
        if (v === 2) throw new Error("predicate failed");
        return true;
      }),
    ),
    /predicate failed/,
  );
});

test("zip closes the side that had values left", async () => {
  const state = {};
  const out = await toArray(zip(endless(state), ["a", "b"]));
  assert.deepEqual(out, [
    [0, "a"],
    [1, "b"],
  ]);
  await flush();
  assert.equal(state.closed, true);
});

test("a channel applies backpressure at its capacity", async () => {
  const ch = channel({ capacity: 2 });
  await ch.push(1);
  await ch.push(2);
  assert.equal(ch.size, 2);

  let accepted = false;
  const third = ch.push(3).then(() => {
    accepted = true;
  });
  await flush();
  assert.equal(accepted, false, "a full channel must make the producer wait");
  assert.equal(ch.size, 2);

  const it = ch.stream[Symbol.asyncIterator]();
  assert.deepEqual(await it.next(), { value: 1, done: false });
  await third;
  assert.equal(accepted, true);
  assert.equal(ch.size, 2);

  assert.deepEqual(await it.next(), { value: 2, done: false });
  assert.deepEqual(await it.next(), { value: 3, done: false });
  ch.close();
  assert.deepEqual(await it.next(), { value: undefined, done: true });
});

test("a consumer waiting on an empty channel gets the next push", async () => {
  const ch = channel();
  const it = ch.stream[Symbol.asyncIterator]();
  let settled = false;
  const pending = it.next().then((r) => {
    settled = true;
    return r;
  });
  await flush();
  assert.equal(settled, false);
  await ch.push("late");
  assert.deepEqual(await pending, { value: "late", done: false });
  ch.close();
  assert.deepEqual(await it.next(), { value: undefined, done: true });
});

test("pushing to a closed channel rejects", async () => {
  const ch = channel();
  ch.close();
  await assert.rejects(ch.push(1));
  assert.equal(ch.size, 0);
});

test("channel size tracks the buffer", async () => {
  const ch = channel({ capacity: 5 });
  assert.equal(ch.size, 0);
  await ch.push("a");
  await ch.push("b");
  assert.equal(ch.size, 2);
  const it = ch.stream[Symbol.asyncIterator]();
  await it.next();
  assert.equal(ch.size, 1);
  ch.close();
  await it.next();
  assert.equal(ch.size, 0);
});

test("take from a channel stops reading it", async () => {
  const ch = channel({ capacity: 10 });
  for (const v of [1, 2, 3, 4]) await ch.push(v);
  const out = await toArray(take(ch.stream, 2));
  assert.deepEqual(out, [1, 2]);
  assert.equal(ch.size, 2, "the untaken values are still buffered");
  ch.close();
});

test("channel rejects a capacity that is not positive", () => {
  for (const bad of [0, -1, "5", NaN, null]) {
    assert.throws(() => channel({ capacity: bad }), RangeError, String(bad));
  }
  assert.doesNotThrow(() => channel({ capacity: Infinity }));
  assert.doesNotThrow(() => channel());
});

test("the combinators validate their arguments", () => {
  assert.throws(() => map([1], null), TypeError);
  assert.throws(() => map([1], "fn"), TypeError);
  assert.throws(() => filter([1], 5), TypeError);
  assert.throws(() => take([1], -1), TypeError);
  assert.throws(() => take([1], 1.5), TypeError);
  assert.throws(() => take([1], "2"), TypeError);
  assert.throws(() => chunk([1], 0), TypeError);
  assert.throws(() => chunk([1], 1.5), TypeError);
  assert.throws(() => pipeline([1], "nope"), TypeError);
});

test("a long pipeline stays lazy end to end", async () => {
  const state = {};
  const out = await toArray(
    pipeline(
      endless(state),
      (s) => filter(s, (v) => v % 2 === 0),
      (s) => map(s, (v) => v * 3),
      (s) => chunk(s, 2),
      (s) => take(s, 2),
    ),
  );
  assert.deepEqual(out, [
    [0, 6],
    [12, 18],
  ]);
  assert.equal(state.produced, 7);
  await flush();
  assert.equal(state.closed, true);
});
