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

async function seed(base, n) {
  const ids = [];
  for (let i = 0; i < n; i++) {
    const res = await f(`${base}/orders`, {
      method: "POST",
      headers: AUTH,
      body: JSON.stringify({ customer: `c${i}`, items: [{ sku: "s", qty: 1 }] }),
    });
    assert.equal(res.status, 201);
    ids.push((await res.json()).id);
  }
  return ids;
}

test("default page is 20 with the full total in X-Total-Count", async () => {
  const { server, base } = await start();
  try {
    await seed(base, 25);
    const res = await f(`${base}/orders`, { headers: AUTH });
    assert.equal(res.status, 200);
    assert.equal(res.headers.get("x-total-count"), "25");
    const page = await res.json();
    assert.equal(page.length, 20);
    assert.equal(page[0].customer, "c0");
    assert.equal(page[19].customer, "c19");
  } finally {
    await stop(server);
  }
});

test("limit and offset slice in insertion order", async () => {
  const { server, base } = await start();
  try {
    await seed(base, 25);
    const res = await f(`${base}/orders?limit=5&offset=22`, { headers: AUTH });
    assert.equal(res.headers.get("x-total-count"), "25");
    const page = await res.json();
    assert.deepEqual(
      page.map((o) => o.customer),
      ["c22", "c23", "c24"],
    );

    const zero = await f(`${base}/orders?limit=0`, { headers: AUTH });
    assert.deepEqual(await zero.json(), []);
    assert.equal(zero.headers.get("x-total-count"), "25");
  } finally {
    await stop(server);
  }
});

test("status filter applies before pagination and the count", async () => {
  const { server, base } = await start();
  try {
    const ids = await seed(base, 10);
    for (const id of [ids[1], ids[3], ids[5]]) {
      const res = await f(`${base}/orders/${id}/cancel`, {
        method: "POST",
        headers: AUTH,
      });
      assert.equal(res.status, 200);
    }

    const cancelled = await f(`${base}/orders?status=cancelled`, {
      headers: AUTH,
    });
    assert.equal(cancelled.headers.get("x-total-count"), "3");
    const cancelledPage = await cancelled.json();
    assert.deepEqual(
      cancelledPage.map((o) => o.customer),
      ["c1", "c3", "c5"],
    );

    const pending = await f(`${base}/orders?status=pending&limit=2`, {
      headers: AUTH,
    });
    assert.equal(pending.headers.get("x-total-count"), "7");
    const pendingPage = await pending.json();
    assert.deepEqual(
      pendingPage.map((o) => o.customer),
      ["c0", "c2"],
    );
  } finally {
    await stop(server);
  }
});

test("an unmatched status filter is empty, not an error", async () => {
  const { server, base } = await start();
  try {
    await seed(base, 3);
    const res = await f(`${base}/orders?status=shipped`, { headers: AUTH });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), []);
    assert.equal(res.headers.get("x-total-count"), "0");
  } finally {
    await stop(server);
  }
});

test("invalid pagination values are rejected", async () => {
  const { server, base } = await start();
  try {
    await seed(base, 3);
    for (const query of ["limit=abc", "offset=-1", "limit=2.5", "offset=nope"]) {
      const res = await f(`${base}/orders?${query}`, { headers: AUTH });
      assert.equal(res.status, 400, query);
      assert.deepEqual(await res.json(), { error: "invalid pagination" });
    }
  } finally {
    await stop(server);
  }
});
