import { test } from "node:test";
import assert from "node:assert/strict";
import { firstError, isValid, rules, validate } from "../src/form";
import type { Rules } from "../src/form";

interface Signup {
  name: string;
  email: string;
  age: number;
  accepted: boolean;
}

const signupRules: Rules<Signup> = {
  name: [rules.required(), rules.minLength(2), rules.maxLength(8)],
  email: [rules.required(), rules.pattern(/^[^@\s]+@[^@\s]+$/)],
  age: [rules.range(18, 120)],
  accepted: [rules.isTrue()],
};

test("a valid form produces an empty error table", () => {
  const errors = validate<Signup>(
    { name: "ada", email: "a@b", age: 40, accepted: true },
    signupRules,
  );
  assert.deepEqual(errors, {});
  assert.equal(isValid(errors), true);
  assert.equal(firstError(errors, ["name", "email", "age", "accepted"]), null);
});

test("each field reports its first failing rule only", () => {
  const errors = validate<Signup>(
    { name: "", email: "nope", age: 5, accepted: false },
    signupRules,
  );
  assert.deepEqual(errors, {
    name: "required",
    email: "invalid format",
    age: "must be between 18 and 120",
    accepted: "must be accepted",
  });
  assert.equal(isValid(errors), false);
});

test("a field with no error gets no key", () => {
  const errors = validate<Signup>(
    { name: "ada", email: "bad", age: 40, accepted: true },
    signupRules,
  );
  assert.deepEqual(Object.keys(errors), ["email"]);
  assert.equal(Object.hasOwn(errors, "name"), false);
});

test("rules run in order and stop at the first failure", () => {
  const seen: string[] = [];
  const trace =
    (tag: string, fail: boolean) =>
    (): string | null => {
      seen.push(tag);
      return fail ? tag : null;
    };
  const errors = validate<{ a: string }>(
    { a: "x" },
    { a: [trace("first", false), trace("second", true), trace("third", true)] },
  );
  assert.deepEqual(errors, { a: "second" });
  assert.deepEqual(seen, ["first", "second"]);
});

test("firstError follows the given order", () => {
  const errors = validate<Signup>(
    { name: "", email: "nope", age: 5, accepted: false },
    signupRules,
  );
  assert.equal(firstError(errors, ["age", "name"]), "must be between 18 and 120");
  assert.equal(firstError(errors, ["name", "age"]), "required");
  assert.equal(firstError(errors, ["accepted"]), "must be accepted");
  assert.equal(firstError(errors, []), null);
});

test("required rejects blank, null and undefined", () => {
  const check = rules.required();
  assert.equal(check(undefined), "required");
  assert.equal(check(null), "required");
  assert.equal(check(""), "required");
  assert.equal(check("   "), "required");
  assert.equal(check("a"), null);
  assert.equal(check(0), null);
  assert.equal(check(false), null);
  assert.equal(check([]), null);
});

test("length rules measure the untrimmed string", () => {
  assert.equal(rules.minLength(3)("ab"), "must be at least 3 characters");
  assert.equal(rules.minLength(3)("ab "), null);
  assert.equal(rules.minLength(3)("abc"), null);
  assert.equal(rules.maxLength(3)("abcd"), "must be at most 3 characters");
  assert.equal(rules.maxLength(3)("abc"), null);
  assert.equal(rules.minLength(0)(""), null);
});

test("range is inclusive and rejects NaN", () => {
  const check = rules.range(1, 5);
  assert.equal(check(1), null);
  assert.equal(check(5), null);
  assert.equal(check(0), "must be between 1 and 5");
  assert.equal(check(6), "must be between 1 and 5");
  assert.equal(check(Number.NaN), "must be between 1 and 5");
});

test("isTrue accepts only true", () => {
  assert.equal(rules.isTrue()(true), null);
  assert.equal(rules.isTrue()(false), "must be accepted");
});

test("pattern is stable across repeated calls even with a global flag", () => {
  const check = rules.pattern(/ab/g);
  assert.equal(check("ab"), null);
  assert.equal(check("ab"), null);
  assert.equal(check("ab"), null);
  const sticky = rules.pattern(/^a/y);
  assert.equal(sticky("abc"), null);
  assert.equal(sticky("abc"), null);
  assert.equal(sticky("bbc"), "invalid format");
});

test("custom messages replace the defaults", () => {
  assert.equal(rules.required("give me one")(""), "give me one");
  assert.equal(rules.minLength(3, "too short")("a"), "too short");
  assert.equal(rules.maxLength(1, "too long")("ab"), "too long");
  assert.equal(rules.pattern(/x/, "nope")("y"), "nope");
  assert.equal(rules.range(1, 2, "out")(9), "out");
  assert.equal(rules.isTrue("tick it")(false), "tick it");
});

test("isValid tolerates an explicitly undefined entry", () => {
  assert.equal(isValid<Signup>({ name: undefined }), true);
  assert.equal(isValid<Signup>({ name: "required" }), false);
});
