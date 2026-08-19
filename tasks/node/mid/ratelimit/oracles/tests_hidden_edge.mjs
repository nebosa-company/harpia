import test from "node:test";
import assert from "node:assert/strict";
import { rateLimit } from "./ratelimit.mjs";

function fakeReq(addr = "10.0.0.1") {
  return { socket: { remoteAddress: addr }, headers: {} };
}

function fakeRes() {
  const headers = {};
  return {
    statusCode: 200,
    body: null,
    ended: false,
    setHeader(name, value) {
      headers[name.toLowerCase()] = value;
    },
    getHeader(name) {
      return headers[name.toLowerCase()];
    },
    end(chunk) {
      this.ended = true;
      this.body = chunk ?? null;
    },
  };
}

function makeClock(start = 5_000_000) {
  let t = start;
  return {
    now: () => t,
    advance: (ms) => {
      t += ms;
    },
  };
}

test("blocked requests never reach the next handler", () => {
  const clock = makeClock();
  const mw = rateLimit({ windowMs: 60_000, max: 1, now: clock.now });
  mw(fakeReq(), fakeRes(), () => {});
  const res = fakeRes();
  let called = 0;
  mw(fakeReq(), res, () => called++);
  assert.equal(res.statusCode, 429);
  assert.equal(called, 0, "next() must not run for a blocked request");
});

test("429 body and headers", () => {
  const clock = makeClock();
  const mw = rateLimit({ windowMs: 60_000, max: 1, now: clock.now });
  mw(fakeReq(), fakeRes(), () => {});
  clock.advance(14_500);
  const res = fakeRes();
  mw(fakeReq(), res, () => {});
  assert.equal(res.statusCode, 429);
  assert.equal(res.getHeader("content-type"), "application/json");
  const body = JSON.parse(res.body);
  assert.equal(body.error, "rate limit exceeded");
  assert.equal(body.retryAfterMs, 45_500);
  assert.equal(res.getHeader("retry-after"), "46");
});

test("blocked requests do not consume quota", () => {
  const clock = makeClock();
  const mw = rateLimit({ windowMs: 10_000, max: 2, now: clock.now });
  mw(fakeReq(), fakeRes(), () => {});
  mw(fakeReq(), fakeRes(), () => {});
  for (let i = 0; i < 5; i++) {
    const res = fakeRes();
    mw(fakeReq(), res, () => {});
    assert.equal(res.statusCode, 429);
  }
  clock.advance(10_000);
  const res = fakeRes();
  let called = 0;
  mw(fakeReq(), res, () => called++);
  assert.equal(called, 1, "hammering while blocked must not extend the block");
  assert.equal(res.statusCode, 200);
});

test("clients are independent", () => {
  const clock = makeClock();
  const mw = rateLimit({ windowMs: 60_000, max: 1, now: clock.now });
  const a = fakeRes();
  mw(fakeReq("10.0.0.1"), a, () => {});
  const aBlocked = fakeRes();
  mw(fakeReq("10.0.0.1"), aBlocked, () => {});
  assert.equal(aBlocked.statusCode, 429);

  const b = fakeRes();
  let bCalled = 0;
  mw(fakeReq("10.0.0.2"), b, () => bCalled++);
  assert.equal(bCalled, 1, "a different client must not be affected");
  assert.equal(b.statusCode, 200);
});

test("custom key function is honored", () => {
  const clock = makeClock();
  const mw = rateLimit({
    windowMs: 60_000,
    max: 1,
    now: clock.now,
    key: (req) => req.headers["x-api-key"],
  });
  const r1 = { socket: { remoteAddress: "1.1.1.1" }, headers: { "x-api-key": "alpha" } };
  const r2 = { socket: { remoteAddress: "1.1.1.1" }, headers: { "x-api-key": "beta" } };
  mw(r1, fakeRes(), () => {});
  const blocked = fakeRes();
  mw(r1, blocked, () => {});
  assert.equal(blocked.statusCode, 429, "same key shares the bucket");
  const ok = fakeRes();
  let called = 0;
  mw(r2, ok, () => called++);
  assert.equal(called, 1, "different key gets its own bucket");
});
