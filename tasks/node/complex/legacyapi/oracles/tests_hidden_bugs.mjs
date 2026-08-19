import test from "node:test";
import assert from "node:assert/strict";
import { createApp } from "./server.mjs";

const TOKEN = "test-token-1";
const AUTH = { Authorization: `Bearer ${TOKEN}` };

// A server that dies mid-request would otherwise leave fetch pending
// forever; every request gets a hard timeout so failures stay failures.
const f = (url, opts = {}) =>
  fetch(url, { ...opts, signal: AbortSignal.timeout(5000) });

async function start() {
  const server = createApp({ tokens: [TOKEN] });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  const { port } = server.address();
  return { server, base: `http://127.0.0.1:${port}` };
}

async function stop(server) {
  server.closeAllConnections?.();
  await new Promise((resolve) => server.close(resolve));
}

async function createOrder(base, customer = "ada") {
  const res = await f(`${base}/orders`, {
    method: "POST",
    headers: AUTH,
    body: JSON.stringify({ customer, items: [{ sku: "widget", qty: 1 }] }),
  });
  assert.equal(res.status, 201, "seed order must be created");
  return res.json();
}

test("cancel with an empty body cancels the order", async () => {
  const { server, base } = await start();
  try {
    const order = await createOrder(base);
    const res = await f(`${base}/orders/${order.id}/cancel`, {
      method: "POST",
      headers: AUTH,
    });
    assert.equal(res.status, 200);
    const updated = await res.json();
    assert.equal(updated.status, "cancelled");
    assert.equal(updated.id, order.id);

    const after = await (
      await f(`${base}/orders/${order.id}`, { headers: AUTH })
    ).json();
    assert.equal(after.status, "cancelled");
  } finally {
    await stop(server);
  }
});

test("cancel with a JSON body works and creates nothing", async () => {
  const { server, base } = await start();
  try {
    const order = await createOrder(base);
    const res = await f(`${base}/orders/${order.id}/cancel`, {
      method: "POST",
      headers: AUTH,
      body: JSON.stringify({ reason: "customer changed their mind" }),
    });
    assert.equal(res.status, 200);
    const list = await (
      await f(`${base}/orders?limit=100`, { headers: AUTH })
    ).json();
    assert.equal(list.length, 1, "a cancel must never create an order");
  } finally {
    await stop(server);
  }
});

test("cancelling twice is 409, unknown ids are 404", async () => {
  const { server, base } = await start();
  try {
    const order = await createOrder(base);
    await f(`${base}/orders/${order.id}/cancel`, { method: "POST", headers: AUTH });
    const again = await f(`${base}/orders/${order.id}/cancel`, {
      method: "POST",
      headers: AUTH,
    });
    assert.equal(again.status, 409);
    assert.deepEqual(await again.json(), { error: "already cancelled" });

    const ghost = await f(`${base}/orders/999/cancel`, {
      method: "POST",
      headers: AUTH,
    });
    assert.equal(ghost.status, 404);
  } finally {
    await stop(server);
  }
});

test("malformed JSON is a 400 and the service survives", async () => {
  const { server, base } = await start();
  try {
    const bad = await f(`${base}/orders`, {
      method: "POST",
      headers: AUTH,
      body: "{definitely not json",
    });
    assert.equal(bad.status, 400);
    const err = await bad.json();
    assert.equal(typeof err.error, "string");

    const empty = await f(`${base}/orders`, { method: "POST", headers: AUTH });
    assert.equal(empty.status, 400);

    const alive = await f(`${base}/orders`, { headers: AUTH });
    assert.equal(alive.status, 200, "the process must survive poison input");
  } finally {
    await stop(server);
  }
});

test("ids are never reused after deletions", async () => {
  const { server, base } = await start();
  try {
    const a = await createOrder(base, "customer-a");
    const b = await createOrder(base, "customer-b");
    const del = await f(`${base}/orders/${a.id}`, {
      method: "DELETE",
      headers: AUTH,
    });
    assert.equal(del.status, 204);

    const c = await createOrder(base, "customer-c");
    assert.notEqual(c.id, b.id, "a fresh order must not reuse a live id");

    const bAgain = await (
      await f(`${base}/orders/${b.id}`, { headers: AUTH })
    ).json();
    assert.equal(bAgain.customer, "customer-b", "existing orders stay intact");
  } finally {
    await stop(server);
  }
});

test("over-long paths are 404", async () => {
  const { server, base } = await start();
  try {
    await createOrder(base);
    for (const [method, path] of [
      ["GET", "/orders/1/extra"],
      ["POST", "/orders/1/cancel/now"],
      ["GET", "/orders/1/cancel/x/y"],
    ]) {
      const res = await f(`${base}${path}`, { method, headers: AUTH });
      assert.equal(res.status, 404, `${method} ${path}`);
    }
  } finally {
    await stop(server);
  }
});

test("every route requires a configured bearer token", async () => {
  const { server, base } = await start();
  try {
    const noAuth = await f(`${base}/orders`);
    assert.equal(noAuth.status, 401);
    assert.deepEqual(await noAuth.json(), { error: "unauthorized" });

    const badToken = await f(`${base}/orders`, {
      headers: { Authorization: "Bearer wrong" },
    });
    assert.equal(badToken.status, 401);

    const badScheme = await f(`${base}/orders`, {
      headers: { Authorization: TOKEN },
    });
    assert.equal(badScheme.status, 401);
  } finally {
    await stop(server);
  }
});
