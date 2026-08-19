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

test("create, read, list", async () => {
  const { server, base } = await start();
  try {
    const created = await fetch(`${base}/notes`, {
      method: "POST",
      body: JSON.stringify({ title: "first", tags: ["a"] }),
    });
    assert.equal(created.status, 201);
    assert.equal(created.headers.get("location"), "/notes/1");
    assert.match(created.headers.get("content-type"), /application\/json/);
    const note = await created.json();
    assert.deepEqual(note, { id: "1", title: "first", body: "", tags: ["a"] });

    const second = await (
      await fetch(`${base}/notes`, {
        method: "POST",
        body: JSON.stringify({ title: "second", body: "text" }),
      })
    ).json();
    assert.deepEqual(second, { id: "2", title: "second", body: "text", tags: [] });

    const one = await fetch(`${base}/notes/1`);
    assert.equal(one.status, 200);
    assert.deepEqual(await one.json(), { id: "1", title: "first", body: "", tags: ["a"] });

    const list = await fetch(`${base}/notes`);
    assert.equal(list.status, 200);
    const notes = await list.json();
    assert.deepEqual(
      notes.map((n) => n.id),
      ["1", "2"],
    );
  } finally {
    await stop(server);
  }
});

test("put replaces the whole note", async () => {
  const { server, base } = await start();
  try {
    await fetch(`${base}/notes`, {
      method: "POST",
      body: JSON.stringify({ title: "orig", body: "keep?", tags: ["x"] }),
    });
    const put = await fetch(`${base}/notes/1`, {
      method: "PUT",
      body: JSON.stringify({ title: "replaced" }),
    });
    assert.equal(put.status, 200);
    assert.deepEqual(await put.json(), {
      id: "1",
      title: "replaced",
      body: "",
      tags: [],
    });
    const got = await (await fetch(`${base}/notes/1`)).json();
    assert.equal(got.body, "");
    assert.deepEqual(got.tags, []);
  } finally {
    await stop(server);
  }
});

test("delete removes and returns 204 with empty body", async () => {
  const { server, base } = await start();
  try {
    await fetch(`${base}/notes`, {
      method: "POST",
      body: JSON.stringify({ title: "bye" }),
    });
    const del = await fetch(`${base}/notes/1`, { method: "DELETE" });
    assert.equal(del.status, 204);
    assert.equal(await del.text(), "");
    const after = await fetch(`${base}/notes/1`);
    assert.equal(after.status, 404);
    const list = await (await fetch(`${base}/notes`)).json();
    assert.deepEqual(list, []);
  } finally {
    await stop(server);
  }
});

test("ids are not reused after a delete", async () => {
  const { server, base } = await start();
  try {
    await fetch(`${base}/notes`, { method: "POST", body: JSON.stringify({ title: "a" }) });
    await fetch(`${base}/notes/1`, { method: "DELETE" });
    const again = await (
      await fetch(`${base}/notes`, { method: "POST", body: JSON.stringify({ title: "b" }) })
    ).json();
    assert.equal(again.id, "2");
  } finally {
    await stop(server);
  }
});
