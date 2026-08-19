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

function makeClock(start = 1_000_000) {
  let t = start;
  return {
    now: () => t,
    advance: (ms) => {
      t += ms;
    },
  };
}

test("allows up to max requests then blocks", () => {
  const clock = makeClock();
  const mw = rateLimit({ windowMs: 60_000, max: 3, now: clock.now });
  for (let i = 0; i < 3; i++) {
    const res = fakeRes();
    let called = 0;
    mw(fakeReq(), res, () => called++);
    assert.equal(called, 1, `request ${i + 1} should pass`);
    assert.equal(res.ended, false);
  }
  const res = fakeRes();
  let called = 0;
  mw(fakeReq(), res, () => called++);
  assert.equal(res.statusCode, 429);
  assert.equal(res.ended, true);
});

test("window expiry fully resets the quota", () => {
  const clock = makeClock();
  const mw = rateLimit({ windowMs: 60_000, max: 2, now: clock.now });
  const hit = () => {
    const res = fakeRes();
    let called = 0;
    mw(fakeReq(), res, () => called++);
    return { res, called };
  };
  hit();
  hit();
  assert.equal(hit().res.statusCode, 429, "third in-window request blocks");

  clock.advance(60_000); // exactly one window later
  const fresh = hit();
  assert.equal(fresh.called, 1, "request after expiry must pass");
  assert.equal(fresh.res.statusCode, 200);
  const second = hit();
  assert.equal(second.called, 1, "fresh window allows max again");
  assert.equal(hit().res.statusCode, 429, "fresh window still enforces max");
});

test("throttled clients recover repeatedly, not just once", () => {
  const clock = makeClock();
  const mw = rateLimit({ windowMs: 1_000, max: 1, now: clock.now });
  for (let round = 0; round < 4; round++) {
    const ok = fakeRes();
    let called = 0;
    mw(fakeReq(), ok, () => called++);
    assert.equal(called, 1, `round ${round}: first request passes`);
    const blocked = fakeRes();
    mw(fakeReq(), blocked, () => {});
    assert.equal(blocked.statusCode, 429, `round ${round}: second blocks`);
    clock.advance(1_000);
  }
});

test("remaining header counts down", () => {
  const clock = makeClock();
  const mw = rateLimit({ windowMs: 60_000, max: 3, now: clock.now });
  const remaining = [];
  for (let i = 0; i < 3; i++) {
    const res = fakeRes();
    mw(fakeReq(), res, () => {});
    remaining.push(res.getHeader("x-ratelimit-remaining"));
    assert.equal(res.getHeader("x-ratelimit-limit"), "3");
  }
  assert.deepEqual(remaining, ["2", "1", "0"]);
});
