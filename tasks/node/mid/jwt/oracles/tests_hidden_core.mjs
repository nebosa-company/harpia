import test from "node:test";
import assert from "node:assert/strict";
import { sign, verify, decode } from "./jwt.mjs";

const NOW_MS = 1_700_000_000_000; // fixed instant
const at = (ms) => ({ now: () => ms });

test("sign produces the exact known token", () => {
  const token = sign({ sub: "user-42", role: "admin" }, "top-secret", {
    expiresIn: 3600,
    now: () => NOW_MS,
  });
  assert.equal(
    token,
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLTQyIiwicm9sZSI6ImFkbWluIiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjE3MDAwMDM2MDB9.g4hotRDRCIaSKWepEAu0DB847iMDXbiFlclbMlPL5yg",
  );
});

test("sign then verify round-trips the claims", () => {
  const token = sign({ sub: "abc" }, "s3cret", { expiresIn: 60, now: () => NOW_MS });
  const payload = verify(token, "s3cret", at(NOW_MS + 1_000));
  assert.deepEqual(payload, { sub: "abc", iat: 1_700_000_000, exp: 1_700_000_060 });
});

test("tampered payload fails with ERR_JWT_SIGNATURE", () => {
  const token = sign({ role: "user" }, "k", { now: () => NOW_MS });
  const [h, p, s] = token.split(".");
  const forged = Buffer.from(
    JSON.stringify({ role: "admin", iat: 1_700_000_000 }),
  ).toString("base64url");
  assert.throws(
    () => verify(`${h}.${forged}.${s}`, "k", at(NOW_MS)),
    (err) => err.code === "ERR_JWT_SIGNATURE",
  );
});

test("wrong secret fails with ERR_JWT_SIGNATURE", () => {
  const token = sign({ a: 1 }, "right", { now: () => NOW_MS });
  assert.throws(
    () => verify(token, "wrong", at(NOW_MS)),
    (err) => err.code === "ERR_JWT_SIGNATURE",
  );
});

test("expiry honors the injected clock", () => {
  const token = sign({ a: 1 }, "k", { expiresIn: 100, now: () => NOW_MS });
  assert.deepEqual(verify(token, "k", at(NOW_MS + 99_000)).a, 1);
  assert.throws(
    () => verify(token, "k", at(NOW_MS + 100_000)),
    (err) => err.code === "ERR_JWT_EXPIRED",
    "exact expiry second is expired",
  );
  assert.throws(
    () => verify(token, "k", at(NOW_MS + 500_000)),
    (err) => err.code === "ERR_JWT_EXPIRED",
  );
});

test("token without exp never expires", () => {
  const token = sign({ a: 1 }, "k", { now: () => NOW_MS });
  const much_later = NOW_MS + 10 * 365 * 24 * 3600 * 1000;
  assert.equal(verify(token, "k", at(much_later)).a, 1);
});
