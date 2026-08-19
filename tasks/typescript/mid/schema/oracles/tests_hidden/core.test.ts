import { test } from "node:test";
import assert from "node:assert/strict";
import { s } from "../src/schema";

test("primitives accept and reject", () => {
  assert.deepEqual(s.string().parse("a"), { ok: true, value: "a" });
  assert.deepEqual(s.string().parse(""), { ok: true, value: "" });
  assert.deepEqual(s.string().parse(1), {
    ok: false,
    issues: [{ path: [], message: "expected string" }],
  });

  assert.deepEqual(s.number().parse(0), { ok: true, value: 0 });
  assert.deepEqual(s.number().parse(-2.5), { ok: true, value: -2.5 });
  assert.deepEqual(s.number().parse("1"), {
    ok: false,
    issues: [{ path: [], message: "expected number" }],
  });
  assert.equal(s.number().parse(Number.NaN).ok, false);
  assert.equal(s.number().parse(Number.POSITIVE_INFINITY).ok, false);

  assert.deepEqual(s.boolean().parse(false), { ok: true, value: false });
  assert.deepEqual(s.boolean().parse(0), {
    ok: false,
    issues: [{ path: [], message: "expected boolean" }],
  });
});

test("literal compares strictly and names itself", () => {
  assert.deepEqual(s.literal("a").parse("a"), { ok: true, value: "a" });
  assert.deepEqual(s.literal("a").parse("b"), {
    ok: false,
    issues: [{ path: [], message: 'expected literal "a"' }],
  });
  assert.deepEqual(s.literal(3).parse(3), { ok: true, value: 3 });
  assert.deepEqual(s.literal(3).parse("3"), {
    ok: false,
    issues: [{ path: [], message: "expected literal 3" }],
  });
  assert.deepEqual(s.literal(true).parse(false), {
    ok: false,
    issues: [{ path: [], message: "expected literal true" }],
  });
});

test("array checks the container and every element", () => {
  const schema = s.array(s.number());
  assert.deepEqual(schema.parse([]), { ok: true, value: [] });
  assert.deepEqual(schema.parse([1, 2]), { ok: true, value: [1, 2] });
  assert.deepEqual(schema.parse("nope"), {
    ok: false,
    issues: [{ path: [], message: "expected array" }],
  });
  assert.deepEqual(schema.parse([1, "x", 3, false]), {
    ok: false,
    issues: [
      { path: [1], message: "expected number" },
      { path: [3], message: "expected number" },
    ],
  });
});

test("object checks the container, reports every field, and ignores extras", () => {
  const schema = s.object({ id: s.number(), name: s.string() });
  assert.deepEqual(schema.parse({ id: 1, name: "a", extra: true }), {
    ok: true,
    value: { id: 1, name: "a" },
  });
  for (const bad of [null, [], "x", 4]) {
    assert.deepEqual(schema.parse(bad), {
      ok: false,
      issues: [{ path: [], message: "expected object" }],
    });
  }
  assert.deepEqual(schema.parse({}), {
    ok: false,
    issues: [
      { path: ["id"], message: "expected number" },
      { path: ["name"], message: "expected string" },
    ],
  });
});

test("optional accepts undefined and a missing key, and is omitted from the output", () => {
  const schema = s.object({ id: s.number(), nickname: s.optional(s.string()) });
  assert.deepEqual(schema.parse({ id: 1 }), { ok: true, value: { id: 1 } });
  assert.deepEqual(schema.parse({ id: 1, nickname: undefined }), {
    ok: true,
    value: { id: 1 },
  });
  assert.deepEqual(schema.parse({ id: 1, nickname: "z" }), {
    ok: true,
    value: { id: 1, nickname: "z" },
  });
  assert.deepEqual(schema.parse({ id: 1, nickname: 5 }), {
    ok: false,
    issues: [{ path: ["nickname"], message: "expected string" }],
  });
});

test("union takes the first match and reports a single issue otherwise", () => {
  const schema = s.union(s.number(), s.literal("none"));
  assert.deepEqual(schema.parse(4), { ok: true, value: 4 });
  assert.deepEqual(schema.parse("none"), { ok: true, value: "none" });
  assert.deepEqual(schema.parse("other"), {
    ok: false,
    issues: [{ path: [], message: "no union member matched" }],
  });
});

test("paths are built from the outside in", () => {
  const schema = s.object({
    user: s.object({ tags: s.array(s.string()) }),
  });
  assert.deepEqual(schema.parse({ user: { tags: ["a", 2, "c", 4] } }), {
    ok: false,
    issues: [
      { path: ["user", "tags", 1], message: "expected string" },
      { path: ["user", "tags", 3], message: "expected string" },
    ],
  });
});

test("a realistic document round-trips", () => {
  const schema = s.object({
    id: s.number(),
    name: s.string(),
    role: s.union(s.literal("admin"), s.literal("member")),
    tags: s.array(s.string()),
    nickname: s.optional(s.string()),
    active: s.boolean(),
  });
  assert.deepEqual(
    schema.parse({
      id: 7,
      name: "ada",
      role: "admin",
      tags: ["x", "y"],
      active: true,
      ignored: 1,
    }),
    {
      ok: true,
      value: { id: 7, name: "ada", role: "admin", tags: ["x", "y"], active: true },
    },
  );
  const failure = schema.parse({ id: "7", name: 1, role: "guest", tags: [1], active: 0 });
  assert.equal(failure.ok, false);
  if (!failure.ok) {
    assert.deepEqual(failure.issues, [
      { path: ["id"], message: "expected number" },
      { path: ["name"], message: "expected string" },
      { path: ["role"], message: "no union member matched" },
      { path: ["tags", 0], message: "expected string" },
      { path: ["active"], message: "expected boolean" },
    ]);
  }
});

test("nested arrays of objects keep their index paths", () => {
  const schema = s.array(s.object({ n: s.number() }));
  assert.deepEqual(schema.parse([{ n: 1 }, { n: "x" }]), {
    ok: false,
    issues: [{ path: [1, "n"], message: "expected number" }],
  });
});
