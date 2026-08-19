import test from "node:test";
import assert from "node:assert/strict";
import { sign, verify, decode } from "./jwt.mjs";

const NOW_MS = 1_700_000_000_000;
const at = (ms) => ({ now: () => ms });

test("payload encoding is base64url without padding", () => {
  const token = sign({ blob: "~~~???>>>" }, "k", { now: () => NOW_MS });
  assert.equal(
    token,
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJibG9iIjoifn5-Pz8_Pj4-IiwiaWF0IjoxNzAwMDAwMDAwfQ.DsFI0icrBahept7zPQpDV15yTH-IcyDFBe1yzrbWFzw",
  );
  assert.ok(!token.includes("="), "no padding");
  assert.ok(!token.includes("+") && !token.includes("/"), "url-safe alphabet");
});

test("nbf gates the token until its time", () => {
  const token = sign({ a: 1 }, "k", { notBefore: 60, now: () => NOW_MS });
  assert.throws(
    () => verify(token, "k", at(NOW_MS + 59_000)),
    (err) => err.code === "ERR_JWT_NOT_BEFORE",
  );
  assert.equal(verify(token, "k", at(NOW_MS + 60_000)).a, 1);
});

test("malformed tokens fail with ERR_JWT_MALFORMED", () => {
  const good = sign({ a: 1 }, "k", { now: () => NOW_MS });
  const [h, p, s] = good.split(".");
  const cases = [
    "definitely-not-a-token",
    `${h}.${p}`,
    `${h}.${p}.${s}.extra`,
    `!!!.${p}.${s}`,
    `${h}.!!!.${s}`,
  ];
  for (const bad of cases) {
    assert.throws(
      () => verify(bad, "k", at(NOW_MS)),
      (err) => err.code === "ERR_JWT_MALFORMED",
      `expected malformed for ${bad.slice(0, 20)}...`,
    );
  }
  assert.throws(
    () => verify(42, "k", at(NOW_MS)),
    (err) => err.code === "ERR_JWT_MALFORMED",
  );
});

test("alg other than HS256 is rejected before signature checks", () => {
  const header = Buffer.from(JSON.stringify({ alg: "none", typ: "JWT" })).toString(
    "base64url",
  );
  const payload = Buffer.from(JSON.stringify({ a: 1 })).toString("base64url");
  assert.throws(
    () => verify(`${header}.${payload}.`, "k", at(NOW_MS)),
    (err) => err.code === "ERR_JWT_MALFORMED",
  );
});

test("computed claims override payload claims", () => {
  const token = sign({ a: 1, iat: 5, exp: 5 }, "k", {
    expiresIn: 100,
    now: () => NOW_MS,
  });
  const payload = verify(token, "k", at(NOW_MS));
  assert.equal(payload.iat, 1_700_000_000);
  assert.equal(payload.exp, 1_700_000_100);
});

test("decode returns header and payload without verifying", () => {
  const token = sign({ x: "y" }, "k", { now: () => NOW_MS });
  const [h, p] = token.split(".");
  const tampered = `${h}.${p}.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA`;
  const decoded = decode(tampered);
  assert.deepEqual(decoded.header, { alg: "HS256", typ: "JWT" });
  assert.deepEqual(decoded.payload, { x: "y", iat: 1_700_000_000 });
  assert.equal(decode("garbage"), null);
  assert.equal(decode(null), null);
});

test("sign validates its inputs", () => {
  assert.throws(() => sign("not an object", "k"), TypeError);
  assert.throws(() => sign(null, "k"), TypeError);
  assert.throws(() => sign({ a: 1 }, 42), TypeError);
});
