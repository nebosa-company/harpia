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

async function* asyncNumbers(...values) {
  for (const value of values) {
    await null;
    yield value;
  }
}

test("fromIterable streams an array", async () => {
  assert.deepEqual(await toArray(fromIterable([1, 2, 3])), [1, 2, 3]);
  assert.deepEqual(await toArray(fromIterable([])), []);
});

test("fromIterable streams a sync generator and a string", async () => {
  function* gen() {
    yield "a";
    yield "b";
  }
  assert.deepEqual(await toArray(fromIterable(gen())), ["a", "b"]);
  assert.deepEqual(await toArray(fromIterable("hi")), ["h", "i"]);
});

test("streams are async iterable", async () => {
  const s = map([1, 2], (v) => v);
  assert.equal(typeof s[Symbol.asyncIterator], "function");
  const seen = [];
  for await (const value of s) seen.push(value);
  assert.deepEqual(seen, [1, 2]);
});

test("map transforms values and passes an index", async () => {
  assert.deepEqual(await toArray(map([1, 2, 3], (v) => v * 2)), [2, 4, 6]);
  assert.deepEqual(await toArray(map(["a", "b"], (v, i) => `${i}:${v}`)), ["0:a", "1:b"]);
});

test("map accepts an async function and an async source", async () => {
  const out = await toArray(map(asyncNumbers(1, 2, 3), async (v) => v + 10));
  assert.deepEqual(out, [11, 12, 13]);
});

test("filter keeps matching values", async () => {
  assert.deepEqual(await toArray(filter([1, 2, 3, 4], (v) => v % 2 === 0)), [2, 4]);
  assert.deepEqual(await toArray(filter([1, 2, 3, 4], async (v) => v > 2)), [3, 4]);
});

test("filter's index counts the values it sees", async () => {
  const out = await toArray(filter(["a", "b", "c", "d"], (v, i) => i % 2 === 0));
  assert.deepEqual(out, ["a", "c"]);
});

test("take limits a stream", async () => {
  assert.deepEqual(await toArray(take([1, 2, 3, 4], 2)), [1, 2]);
  assert.deepEqual(await toArray(take([1, 2], 10)), [1, 2]);
  assert.deepEqual(await toArray(take([1, 2], 0)), []);
});

test("chunk groups values", async () => {
  assert.deepEqual(await toArray(chunk([1, 2, 3, 4], 2)), [
    [1, 2],
    [3, 4],
  ]);
  assert.deepEqual(await toArray(chunk([1, 2, 3, 4, 5], 2)), [[1, 2], [3, 4], [5]]);
  assert.deepEqual(await toArray(chunk([], 3)), []);
  assert.deepEqual(await toArray(chunk([1, 2], 1)), [[1], [2]]);
});

test("concat runs sources in order", async () => {
  assert.deepEqual(await toArray(concat([1, 2], asyncNumbers(3), [4])), [1, 2, 3, 4]);
  assert.deepEqual(await toArray(concat()), []);
  assert.deepEqual(await toArray(concat([], [])), []);
});

test("zip pairs values and stops at the shorter side", async () => {
  assert.deepEqual(await toArray(zip([1, 2, 3], ["a", "b", "c"])), [
    [1, "a"],
    [2, "b"],
    [3, "c"],
  ]);
  assert.deepEqual(await toArray(zip([1, 2, 3], ["a"])), [[1, "a"]]);
  assert.deepEqual(await toArray(zip([], [1, 2])), []);
  assert.deepEqual(await toArray(zip(asyncNumbers(1, 2), ["x", "y"])), [
    [1, "x"],
    [2, "y"],
  ]);
});

test("pipeline applies operators in order", async () => {
  const out = await toArray(
    pipeline(
      [1, 2, 3, 4, 5, 6],
      (s) => filter(s, (v) => v % 2 === 0),
      (s) => map(s, (v) => v * 10),
      (s) => take(s, 2),
    ),
  );
  assert.deepEqual(out, [20, 40]);
});

test("pipeline with no operators is the source", async () => {
  assert.deepEqual(await toArray(pipeline([1, 2])), [1, 2]);
});

test("combinators compose directly too", async () => {
  const out = await toArray(chunk(map(filter([1, 2, 3, 4, 5, 6], (v) => v > 2), (v) => v * 2), 2));
  assert.deepEqual(out, [
    [6, 8],
    [10, 12],
  ]);
});

test("a channel delivers pushed values", async () => {
  const ch = channel();
  const collected = toArray(ch.stream);
  await ch.push(1);
  await ch.push(2);
  ch.close();
  assert.deepEqual(await collected, [1, 2]);
});

test("a channel closed with values buffered still drains them", async () => {
  const ch = channel();
  ch.push("a");
  ch.push("b");
  ch.close();
  assert.deepEqual(await toArray(ch.stream), ["a", "b"]);
});

test("an empty closed channel ends at once", async () => {
  const ch = channel();
  ch.close();
  assert.deepEqual(await toArray(ch.stream), []);
});

test("channel values flow through combinators", async () => {
  const ch = channel();
  const collected = toArray(map(ch.stream, (v) => v * 2));
  for (const v of [1, 2, 3]) await ch.push(v);
  ch.close();
  assert.deepEqual(await collected, [2, 4, 6]);
});
