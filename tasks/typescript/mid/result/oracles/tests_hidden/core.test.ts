import { test } from "node:test";
import assert from "node:assert/strict";
import {
  all,
  andThen,
  err,
  fromThrowable,
  isErr,
  isOk,
  map,
  mapErr,
  orElse,
  partition,
  ok,
  unwrapOr,
  unwrapOrElse,
} from "../src/result";

test("constructors build the two shapes", () => {
  assert.deepEqual(ok(1), { ok: true, value: 1 });
  assert.deepEqual(err("boom"), { ok: false, error: "boom" });
  assert.deepEqual(ok(undefined), { ok: true, value: undefined });
});

test("guards agree with the tag", () => {
  assert.equal(isOk(ok(1)), true);
  assert.equal(isErr(ok(1)), false);
  assert.equal(isOk(err("x")), false);
  assert.equal(isErr(err("x")), true);
});

test("map transforms the value and leaves an error alone", () => {
  assert.deepEqual(map(ok(2), (n) => n * 3), { ok: true, value: 6 });
  let ran = false;
  const kept = map(err("boom"), () => {
    ran = true;
    return 1;
  });
  assert.deepEqual(kept, { ok: false, error: "boom" });
  assert.equal(ran, false);
});

test("mapErr transforms the error and leaves a value alone", () => {
  assert.deepEqual(mapErr(err("boom"), (e) => `${e}!`), { ok: false, error: "boom!" });
  let ran = false;
  const kept = mapErr(ok(2), () => {
    ran = true;
    return "x";
  });
  assert.deepEqual(kept, { ok: true, value: 2 });
  assert.equal(ran, false);
});

test("combinators return fresh objects", () => {
  const source = ok(1);
  const mapped = map(source, (n) => n);
  assert.notEqual(mapped, source);
  assert.deepEqual(mapped, source);
});

test("andThen chains and short-circuits", () => {
  const parse = (raw: string) =>
    raw === "" ? err("parse" as const) : ok(Number(raw));
  const check = (n: number) => (n > 10 ? err("range" as const) : ok(n));

  assert.deepEqual(andThen(parse("4"), check), { ok: true, value: 4 });
  assert.deepEqual(andThen(parse("40"), check), { ok: false, error: "range" });
  assert.deepEqual(andThen(parse(""), check), { ok: false, error: "parse" });

  let ran = false;
  andThen(err("first"), () => {
    ran = true;
    return ok(1);
  });
  assert.equal(ran, false);
});

test("orElse recovers and short-circuits", () => {
  assert.deepEqual(orElse(err("boom"), () => ok(0)), { ok: true, value: 0 });
  assert.deepEqual(orElse(err("boom"), (e) => err(`${e}?`)), {
    ok: false,
    error: "boom?",
  });
  let ran = false;
  const kept = orElse(ok(5), () => {
    ran = true;
    return ok(0);
  });
  assert.deepEqual(kept, { ok: true, value: 5 });
  assert.equal(ran, false);
});

test("unwrapOr and unwrapOrElse", () => {
  assert.equal(unwrapOr(ok(3), 9), 3);
  assert.equal(unwrapOr(err("x"), 9), 9);
  assert.equal(unwrapOrElse(ok(3), () => 9), 3);
  assert.equal(unwrapOrElse(err("boom"), (e) => e.length), 4);
});

test("all collects a tuple or the leftmost error", () => {
  assert.deepEqual(all([ok(1), ok("a"), ok(true)]), {
    ok: true,
    value: [1, "a", true],
  });
  assert.deepEqual(all([]), { ok: true, value: [] });
  assert.deepEqual(all([ok(1), err("first"), err("second")]), {
    ok: false,
    error: "first",
  });
  assert.deepEqual(all([err("only"), ok(2)]), { ok: false, error: "only" });
});

test("all hands back the failing result unchanged", () => {
  const failure = err("boom");
  assert.equal(all([ok(1), failure]), failure);
});

test("partition splits in input order", () => {
  assert.deepEqual(partition([ok(1), err("a"), ok(2), err("b")]), {
    values: [1, 2],
    errors: ["a", "b"],
  });
  assert.deepEqual(partition([]), { values: [], errors: [] });
  assert.deepEqual(partition([ok(1)]), { values: [1], errors: [] });
  assert.deepEqual(partition([err("a")]), { values: [], errors: ["a"] });
});

test("fromThrowable wraps success and failure and keeps the arguments", () => {
  const parse = fromThrowable(
    (raw: string, radix: number): number => {
      const n = Number.parseInt(raw, radix);
      if (Number.isNaN(n)) throw new RangeError(`bad number: ${raw}`);
      return n;
    },
    (cause) => (cause instanceof Error ? cause.message : String(cause)),
  );
  assert.deepEqual(parse("ff", 16), { ok: true, value: 255 });
  assert.deepEqual(parse("zz", 16), { ok: false, error: "bad number: zz" });
});

test("fromThrowable catches non-Error throws too", () => {
  const boom = fromThrowable(
    (): number => {
      throw "plain string";
    },
    (cause) => String(cause),
  );
  assert.deepEqual(boom(), { ok: false, error: "plain string" });
});
