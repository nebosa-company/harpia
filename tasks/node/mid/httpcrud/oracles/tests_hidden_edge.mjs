import test from "node:test";
import assert from "node:assert/strict";
import { createApp } from "./app.mjs";

async function start() {
  const server = createApp();
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

test("validation failures return 400 with a JSON error", async () => {
  const { server, base } = await start();
  try {
    const cases = [
      "not json at all",
      JSON.stringify("a string"),
      JSON.stringify([1, 2]),
      JSON.stringify({}),
      JSON.stringify({ title: "" }),
      JSON.stringify({ title: 42 }),
      JSON.stringify({ title: "ok", body: 7 }),
      JSON.stringify({ title: "ok", tags: "nope" }),
      JSON.stringify({ title: "ok", tags: [1] }),
    ];
    for (const body of cases) {
      const res = await fetch(`${base}/notes`, { method: "POST", body });
      assert.equal(res.status, 400, `expected 400 for body: ${body}`);
      assert.match(res.headers.get("content-type"), /application\/json/);
      const err = await res.json();
      assert.equal(typeof err.error, "string");
    }
    const list = await (await fetch(`${base}/notes`)).json();
    assert.deepEqual(list, [], "invalid posts must not create notes");
  } finally {
    await stop(server);
  }
});

test("404 for unknown ids and unknown paths", async () => {
  const { server, base } = await start();
  try {
    for (const path of ["/notes/99", "/nope", "/notes/1/extra"]) {
      const res = await fetch(`${base}${path}`);
      assert.equal(res.status, 404, `expected 404 for ${path}`);
      const err = await res.json();
      assert.equal(typeof err.error, "string");
    }
    const put = await fetch(`${base}/notes/99`, {
      method: "PUT",
      body: JSON.stringify({ title: "ghost" }),
    });
    assert.equal(put.status, 404, "PUT must not create");
    const del = await fetch(`${base}/notes/99`, { method: "DELETE" });
    assert.equal(del.status, 404);
  } finally {
    await stop(server);
  }
});

test("405 with Allow header on wrong methods", async () => {
  const { server, base } = await start();
  try {
    const onCollection = await fetch(`${base}/notes`, { method: "DELETE" });
    assert.equal(onCollection.status, 405);
    assert.equal(onCollection.headers.get("allow"), "GET, POST");

    await fetch(`${base}/notes`, { method: "POST", body: JSON.stringify({ title: "x" }) });
    const onItem = await fetch(`${base}/notes/1`, { method: "POST", body: "{}" });
    assert.equal(onItem.status, 405);
    assert.equal(onItem.headers.get("allow"), "GET, PUT, DELETE");
  } finally {
    await stop(server);
  }
});

test("two apps are fully isolated", async () => {
  const a = await start();
  const b = await start();
  try {
    await fetch(`${a.base}/notes`, {
      method: "POST",
      body: JSON.stringify({ title: "only in a" }),
    });
    const inB = await (await fetch(`${b.base}/notes`)).json();
    assert.deepEqual(inB, []);
    const fresh = await (
      await fetch(`${b.base}/notes`, { method: "POST", body: JSON.stringify({ title: "b1" }) })
    ).json();
    assert.equal(fresh.id, "1", "each app numbers its own notes");
  } finally {
    await stop(a.server);
    await stop(b.server);
  }
});
