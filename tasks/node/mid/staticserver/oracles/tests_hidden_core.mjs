import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { createStaticServer } from "./static_server.mjs";

async function start() {
  const server = createStaticServer("public");
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

const etagOf = (buf) => `"${createHash("sha1").update(buf).digest("hex")}"`;

test("serves files with type, length, etag and accept-ranges", async () => {
  const { server, base } = await start();
  try {
    const bytes = await readFile("public/data.json");
    const res = await fetch(`${base}/data.json`);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get("content-type"), "application/json");
    assert.equal(res.headers.get("content-length"), String(bytes.length));
    assert.equal(res.headers.get("etag"), etagOf(bytes));
    assert.equal(res.headers.get("accept-ranges"), "bytes");
    assert.deepEqual(Buffer.from(await res.arrayBuffer()), bytes);
  } finally {
    await stop(server);
  }
});

test("root path serves index.html", async () => {
  const { server, base } = await start();
  try {
    const bytes = await readFile("public/index.html");
    const res = await fetch(`${base}/`);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get("content-type"), "text/html");
    assert.deepEqual(Buffer.from(await res.arrayBuffer()), bytes);
  } finally {
    await stop(server);
  }
});

test("nested paths and css/js types", async () => {
  const { server, base } = await start();
  try {
    const css = await fetch(`${base}/assets/styles.css`);
    assert.equal(css.status, 200);
    assert.equal(css.headers.get("content-type"), "text/css");
    const js = await fetch(`${base}/assets/app.js`);
    assert.equal(js.status, 200);
    assert.equal(js.headers.get("content-type"), "text/javascript");
  } finally {
    await stop(server);
  }
});

test("if-none-match with the current etag yields 304", async () => {
  const { server, base } = await start();
  try {
    const bytes = await readFile("public/notes.txt");
    const etag = etagOf(bytes);
    const res = await fetch(`${base}/notes.txt`, {
      headers: { "If-None-Match": etag },
    });
    assert.equal(res.status, 304);
    assert.equal(res.headers.get("etag"), etag);
    assert.equal((await res.text()).length, 0);

    const star = await fetch(`${base}/notes.txt`, {
      headers: { "If-None-Match": "*" },
    });
    assert.equal(star.status, 304);

    const stale = await fetch(`${base}/notes.txt`, {
      headers: { "If-None-Match": '"deadbeef"' },
    });
    assert.equal(stale.status, 200);
  } finally {
    await stop(server);
  }
});

test("basic byte range returns 206 with the slice", async () => {
  const { server, base } = await start();
  try {
    const bytes = await readFile("public/notes.txt");
    const res = await fetch(`${base}/notes.txt`, {
      headers: { Range: "bytes=0-9" },
    });
    assert.equal(res.status, 206);
    assert.equal(res.headers.get("content-range"), `bytes 0-9/${bytes.length}`);
    assert.equal(res.headers.get("content-length"), "10");
    assert.deepEqual(Buffer.from(await res.arrayBuffer()), bytes.subarray(0, 10));
  } finally {
    await stop(server);
  }
});

test("404 for missing files and directories", async () => {
  const { server, base } = await start();
  try {
    const missing = await fetch(`${base}/nope.txt`);
    assert.equal(missing.status, 404);
    assert.equal(await missing.text(), "Not Found");
    const dir = await fetch(`${base}/assets`);
    assert.equal(dir.status, 404);
  } finally {
    await stop(server);
  }
});
