import { test } from "node:test";
import assert from "node:assert/strict";
import { createContainer, token, tokenName } from "../src/container";

interface Logger {
  lines: string[];
}
interface Repo {
  logger: Logger;
  id: number;
}

const LOGGER = token<Logger>("logger");
const REPO = token<Repo>("repo");
const PORT = token<number>("port");

test("tokenName reads the name back", () => {
  assert.equal(tokenName(LOGGER), "logger");
  assert.equal(tokenName(PORT), "port");
});

test("registerValue and resolve", () => {
  const c = createContainer();
  c.registerValue(PORT, 8080);
  assert.equal(c.resolve(PORT), 8080);
});

test("register returns the container so calls chain", () => {
  const c = createContainer();
  const same = c.register(PORT, () => 1).registerValue(LOGGER, { lines: [] });
  assert.equal(same, c);
  assert.equal(c.resolve(PORT), 1);
});

test("a factory runs once and its instance is reused", () => {
  const c = createContainer();
  let built = 0;
  c.register(LOGGER, () => {
    built += 1;
    return { lines: [] };
  });
  const a = c.resolve(LOGGER);
  const b = c.resolve(LOGGER);
  assert.equal(built, 1);
  assert.equal(a, b);
});

test("a factory receives the resolving container", () => {
  const c = createContainer();
  let seen: unknown = null;
  c.registerValue(LOGGER, { lines: [] });
  c.register(REPO, (inner) => {
    seen = inner;
    return { logger: inner.resolve(LOGGER), id: 1 };
  });
  const repo = c.resolve(REPO);
  assert.equal(seen, c);
  assert.equal(repo.logger, c.resolve(LOGGER));
});

test("re-registering replaces the factory and drops the built instance", () => {
  const c = createContainer();
  c.register(PORT, () => 1);
  assert.equal(c.resolve(PORT), 1);
  c.register(PORT, () => 2);
  assert.equal(c.resolve(PORT), 2);
  c.registerValue(PORT, 3);
  assert.equal(c.resolve(PORT), 3);
});

test("an unregistered token is a RangeError naming it", () => {
  const c = createContainer();
  assert.throws(
    () => c.resolve(REPO),
    (err: unknown) =>
      err instanceof RangeError && err.message === "unregistered token: repo",
  );
});

test("has follows registrations, including inherited ones", () => {
  const c = createContainer();
  assert.equal(c.has(PORT), false);
  c.registerValue(PORT, 1);
  assert.equal(c.has(PORT), true);
  const child = c.createScope();
  assert.equal(child.has(PORT), true);
  assert.equal(child.has(REPO), false);
});

test("a cycle is reported with the whole chain", () => {
  const A = token<number>("a");
  const B = token<number>("b");
  const c = createContainer();
  c.register(A, (inner) => inner.resolve(B));
  c.register(B, (inner) => inner.resolve(A));
  assert.throws(
    () => c.resolve(A),
    (err: unknown) =>
      err instanceof RangeError && err.message === "circular dependency: a -> b -> a",
  );
});

test("a self-cycle is reported too", () => {
  const A = token<number>("a");
  const c = createContainer();
  c.register(A, (inner) => inner.resolve(A));
  assert.throws(
    () => c.resolve(A),
    (err: unknown) =>
      err instanceof RangeError && err.message === "circular dependency: a -> a",
  );
});

test("the container still works after a cycle was reported", () => {
  const A = token<number>("a");
  const B = token<number>("b");
  const c = createContainer();
  c.register(A, (inner) => inner.resolve(B));
  c.register(B, (inner) => inner.resolve(A));
  assert.throws(() => c.resolve(A), RangeError);
  c.registerValue(PORT, 42);
  assert.equal(c.resolve(PORT), 42);
  c.registerValue(B, 7);
  assert.equal(c.resolve(A), 7);
});

test("a scope keeps its own instances", () => {
  const c = createContainer();
  let built = 0;
  c.register(LOGGER, () => {
    built += 1;
    return { lines: [] };
  });
  const parentLogger = c.resolve(LOGGER);
  const child = c.createScope();
  const childLogger = child.resolve(LOGGER);
  assert.equal(built, 2);
  assert.notEqual(childLogger, parentLogger);
  assert.equal(child.resolve(LOGGER), childLogger);
  assert.equal(c.resolve(LOGGER), parentLogger);
});

test("a factory run for a scope receives the scope", () => {
  const c = createContainer();
  c.register(LOGGER, () => ({ lines: [] }));
  let seen: unknown = null;
  c.register(REPO, (inner) => {
    seen = inner;
    return { logger: inner.resolve(LOGGER), id: 1 };
  });
  const child = c.createScope();
  const repo = child.resolve(REPO);
  assert.equal(seen, child);
  assert.equal(repo.logger, child.resolve(LOGGER));
  assert.notEqual(repo.logger, c.resolve(LOGGER));
});

test("registering on a scope leaves the parent alone", () => {
  const c = createContainer();
  c.registerValue(PORT, 1);
  const child = c.createScope();
  child.registerValue(PORT, 2);
  assert.equal(child.resolve(PORT), 2);
  assert.equal(c.resolve(PORT), 1);
});

test("scopes nest", () => {
  const c = createContainer();
  c.registerValue(PORT, 1);
  const grandchild = c.createScope().createScope();
  assert.equal(grandchild.has(PORT), true);
  assert.equal(grandchild.resolve(PORT), 1);
});
