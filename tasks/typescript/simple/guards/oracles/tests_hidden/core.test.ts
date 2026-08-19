import { test } from "node:test";
import assert from "node:assert/strict";
import {
  MESSAGE_KINDS,
  assertMessage,
  assertMessageOfKind,
  describe,
  isMessage,
  isMessageOfKind,
} from "../src/messages";

test("MESSAGE_KINDS lists the four kinds in order", () => {
  assert.deepEqual(MESSAGE_KINDS, ["ping", "chat", "join", "error"]);
});

test("well-formed messages are accepted", () => {
  assert.equal(isMessage({ kind: "ping", nonce: 0 }), true);
  assert.equal(isMessage({ kind: "ping", nonce: -3.5 }), true);
  assert.equal(isMessage({ kind: "chat", from: "ada", body: "" }), true);
  assert.equal(isMessage({ kind: "join", room: "lobby", members: [] }), true);
  assert.equal(isMessage({ kind: "join", room: "lobby", members: ["a", "b"] }), true);
  assert.equal(isMessage({ kind: "error", code: 404 }), true);
  assert.equal(isMessage({ kind: "error", code: 404, detail: undefined }), true);
  assert.equal(isMessage({ kind: "error", code: -1, detail: "gone" }), true);
});

test("extra properties are tolerated", () => {
  assert.equal(isMessage({ kind: "ping", nonce: 1, seq: 9, trace: "x" }), true);
});

test("non-objects and arrays are rejected", () => {
  for (const bad of [null, undefined, 1, "ping", true, [], [{ kind: "ping", nonce: 1 }]]) {
    assert.equal(isMessage(bad), false, `expected ${JSON.stringify(bad)} to be rejected`);
  }
});

test("unknown or missing kinds are rejected", () => {
  assert.equal(isMessage({}), false);
  assert.equal(isMessage({ kind: "leave", room: "x" }), false);
  assert.equal(isMessage({ kind: 1 }), false);
  assert.equal(isMessage({ kind: "Ping", nonce: 1 }), false);
});

test("payload rules are enforced per kind", () => {
  assert.equal(isMessage({ kind: "ping" }), false);
  assert.equal(isMessage({ kind: "ping", nonce: "1" }), false);
  assert.equal(isMessage({ kind: "ping", nonce: Number.NaN }), false);
  assert.equal(isMessage({ kind: "ping", nonce: Number.POSITIVE_INFINITY }), false);

  assert.equal(isMessage({ kind: "chat", from: "", body: "hi" }), false);
  assert.equal(isMessage({ kind: "chat", from: "ada" }), false);
  assert.equal(isMessage({ kind: "chat", from: "ada", body: 1 }), false);

  assert.equal(isMessage({ kind: "join", room: "", members: [] }), false);
  assert.equal(isMessage({ kind: "join", room: "lobby" }), false);
  assert.equal(isMessage({ kind: "join", room: "lobby", members: "a" }), false);
  assert.equal(isMessage({ kind: "join", room: "lobby", members: ["a", 2] }), false);

  assert.equal(isMessage({ kind: "error" }), false);
  assert.equal(isMessage({ kind: "error", code: 1.5 }), false);
  assert.equal(isMessage({ kind: "error", code: 1, detail: 2 }), false);
  assert.equal(isMessage({ kind: "error", code: 1, detail: null }), false);
});

test("isMessageOfKind matches only the asked-for kind", () => {
  const ping = { kind: "ping", nonce: 1 };
  assert.equal(isMessageOfKind(ping, "ping"), true);
  assert.equal(isMessageOfKind(ping, "chat"), false);
  assert.equal(isMessageOfKind({ kind: "chat", from: "a", body: "b" }, "chat"), true);
  assert.equal(isMessageOfKind({ kind: "chat", from: "", body: "b" }, "chat"), false);
  assert.equal(isMessageOfKind(null, "ping"), false);
});

test("assertMessage passes valid values and throws TypeError otherwise", () => {
  assert.equal(assertMessage({ kind: "ping", nonce: 1 }), undefined);
  assert.throws(
    () => assertMessage({ kind: "nope" }),
    (err: unknown) => err instanceof TypeError && err.message === "invalid message",
  );
});

test("assertMessageOfKind names the kind it wanted", () => {
  assert.equal(assertMessageOfKind({ kind: "join", room: "r", members: [] }, "join"), undefined);
  assert.throws(
    () => assertMessageOfKind({ kind: "ping", nonce: 1 }, "chat"),
    (err: unknown) => err instanceof TypeError && err.message === 'expected message kind "chat"',
  );
  assert.throws(
    () => assertMessageOfKind(42, "error"),
    (err: unknown) => err instanceof TypeError && err.message === 'expected message kind "error"',
  );
});

test("describe renders each member", () => {
  assert.equal(describe({ kind: "ping", nonce: 7 }), "ping #7");
  assert.equal(describe({ kind: "chat", from: "ada", body: "hello" }), "ada: hello");
  assert.equal(describe({ kind: "chat", from: "ada", body: "" }), "ada: ");
  assert.equal(describe({ kind: "join", room: "lobby", members: [] }), "lobby (0 members)");
  assert.equal(
    describe({ kind: "join", room: "lobby", members: ["a", "b"] }),
    "lobby (2 members)",
  );
  assert.equal(describe({ kind: "error", code: 500 }), "error 500");
  assert.equal(describe({ kind: "error", code: 500, detail: undefined }), "error 500");
  assert.equal(describe({ kind: "error", code: 404, detail: "gone" }), "error 404: gone");
});
