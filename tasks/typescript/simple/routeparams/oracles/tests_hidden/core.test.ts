import { test } from "node:test";
import assert from "node:assert/strict";
import { buildPath, matchRoute, paramNames } from "../src/route";

test("a literal route matches itself and captures nothing", () => {
  assert.deepEqual(matchRoute("/health", "/health"), {});
  assert.deepEqual(matchRoute("/", "/"), {});
});

test("parameters are captured by name", () => {
  assert.deepEqual(matchRoute("/users/:id", "/users/42"), { id: "42" });
  assert.deepEqual(matchRoute("/users/:id/posts/:postId", "/users/7/posts/9"), {
    id: "7",
    postId: "9",
  });
});

test("one trailing slash is ignored on both sides", () => {
  assert.deepEqual(matchRoute("/users/:id", "/users/42/"), { id: "42" });
  assert.deepEqual(matchRoute("/users/:id/", "/users/42"), { id: "42" });
});

test("mismatched shapes return null", () => {
  assert.equal(matchRoute("/users/:id", "/users"), null);
  assert.equal(matchRoute("/users/:id", "/users/42/extra"), null);
  assert.equal(matchRoute("/users/:id", "/accounts/42"), null);
  assert.equal(matchRoute("/users/:id", "/Users/42"), null);
  assert.equal(matchRoute("/", "/x"), null);
});

test("an empty segment never fills a parameter", () => {
  assert.equal(matchRoute("/users/:id", "/users/"), null);
  assert.equal(matchRoute("/users/:id/edit", "/users//edit"), null);
});

test("captured values are percent-decoded", () => {
  assert.deepEqual(matchRoute("/files/:name", "/files/a%20b"), { name: "a b" });
  assert.deepEqual(matchRoute("/files/:name", "/files/%C3%A9"), { name: "é" });
});

test("buildPath substitutes and encodes", () => {
  assert.equal(buildPath("/health", {}), "/health");
  assert.equal(buildPath("/users/:id", { id: "42" }), "/users/42");
  assert.equal(
    buildPath("/users/:id/posts/:postId", { id: "7", postId: "9" }),
    "/users/7/posts/9",
  );
  assert.equal(buildPath("/files/:name", { name: "a b" }), "/files/a%20b");
  assert.equal(buildPath("/files/:name", { name: "a/b" }), "/files/a%2Fb");
});

test("buildPath refuses a missing or empty value", () => {
  const noId = {} as unknown as { id: string };
  assert.throws(
    () => buildPath("/users/:id", noId),
    (err: unknown) =>
      err instanceof TypeError && err.message === 'missing route parameter "id"',
  );
  assert.throws(
    () => buildPath("/users/:id", { id: "" }),
    (err: unknown) =>
      err instanceof TypeError && err.message === 'missing route parameter "id"',
  );
  assert.throws(
    () => buildPath("/a/:first/b/:second", { first: "x", second: "" }),
    (err: unknown) =>
      err instanceof TypeError && err.message === 'missing route parameter "second"',
  );
});

test("buildPath and matchRoute round-trip", () => {
  const built = buildPath("/users/:id/posts/:postId", { id: "a b", postId: "c/d" });
  assert.deepEqual(matchRoute("/users/:id/posts/:postId", built), {
    id: "a b",
    postId: "c/d",
  });
});

test("paramNames lists names in order", () => {
  assert.deepEqual(paramNames("/users/:id/posts/:postId"), ["id", "postId"]);
  assert.deepEqual(paramNames("/health"), []);
  assert.deepEqual(paramNames("/"), []);
  assert.deepEqual(paramNames("/:a/:b/:c"), ["a", "b", "c"]);
});
