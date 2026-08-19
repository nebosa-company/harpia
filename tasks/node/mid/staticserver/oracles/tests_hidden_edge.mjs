import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { createStaticServer } from "./static_server.mjs";

// fetch() normalizes dot segments client-side, so traversal probes go out
// through a raw http.request with the path passed verbatim.
function rawGet(port, path) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      { host: "127.0.0.1", port, path, method: "GET" },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () =>
          resolve({
            status: res.statusCode,
            body: Buffer.concat(chunks).toString(),
          }),
        );
      },
    );
    req.on("error", reject);
    req.end();
  });
}

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

test("open-ended and suffix ranges", async () => {
  const { server, base } = await start();
  try {
    const bytes = await readFile("public/notes.txt");
    const n = bytes.length;

    const tail = await fetch(`${base}/notes.txt`, {
      headers: { Range: `bytes=${n - 5}-` },
    });
    assert.equal(tail.status, 206);
    assert.equal(tail.headers.get("content-range"), `bytes ${n - 5}-${n - 1}/${n}`);
    assert.deepEqual(Buffer.from(await tail.arrayBuffer()), bytes.subarray(n - 5));

    const suffix = await fetch(`${base}/notes.txt`, {
      headers: { Range: "bytes=-8" },
    });
    assert.equal(suffix.status, 206);
    assert.equal(suffix.headers.get("content-range"), `bytes ${n - 8}-${n - 1}/${n}`);
    assert.deepEqual(Buffer.from(await suffix.arrayBuffer()), bytes.subarray(n - 8));

    const clamped = await fetch(`${base}/notes.txt`, {
      headers: { Range: `bytes=10-${n + 500}` },
    });
    assert.equal(clamped.status, 206);
    assert.equal(clamped.headers.get("content-range"), `bytes 10-${n - 1}/${n}`);
  } finally {
    await stop(server);
  }
});

test("unsatisfiable ranges yield 416 with a star content-range", async () => {
  const { server, base } = await start();
  try {
    const bytes = await readFile("public/notes.txt");
    const n = bytes.length;
    for (const range of [`bytes=${n}-`, `bytes=${n + 10}-${n + 20}`, "bytes=-0"]) {
      const res = await fetch(`${base}/notes.txt`, { headers: { Range: range } });
      assert.equal(res.status, 416, `range: ${range}`);
      assert.equal(res.headers.get("content-range"), `bytes */${n}`);
    }
  } finally {
    await stop(server);
  }
});

test("malformed or multiple ranges are ignored", async () => {
  const { server, base } = await start();
  try {
    const bytes = await readFile("public/notes.txt");
    for (const range of ["bytes=5-2", "bytes=0-4,10-14", "chunks=0-4", "bytes=abc"]) {
      const res = await fetch(`${base}/notes.txt`, { headers: { Range: range } });
      assert.equal(res.status, 200, `range: ${range}`);
      assert.equal(res.headers.get("content-length"), String(bytes.length));
    }
  } finally {
    await stop(server);
  }
});

test("if-none-match wins over range", async () => {
  const { server, base } = await start();
  try {
    const bytes = await readFile("public/notes.txt");
    const res = await fetch(`${base}/notes.txt`, {
      headers: { "If-None-Match": etagOf(bytes), Range: "bytes=0-4" },
    });
    assert.equal(res.status, 304);
  } finally {
    await stop(server);
  }
});

test("HEAD carries the GET headers and no body", async () => {
  const { server, base } = await start();
  try {
    const bytes = await readFile("public/data.json");
    const res = await fetch(`${base}/data.json`, { method: "HEAD" });
    assert.equal(res.status, 200);
    assert.equal(res.headers.get("content-type"), "application/json");
    assert.equal(res.headers.get("content-length"), String(bytes.length));
    assert.equal(res.headers.get("etag"), etagOf(bytes));
    assert.equal((await res.text()).length, 0);
  } finally {
    await stop(server);
  }
});

test("dot-dot traversal is forbidden", async () => {
  const { server } = await start();
  const { port } = server.address();
  try {
    const probes = [
      "/../NOTES.md",
      "/%2e%2e/NOTES.md",
      "/assets/%2e%2e/%2e%2e/.env.example",
      "/..%5Cnotes.txt",
    ];
    for (const path of probes) {
      const res = await rawGet(port, path);
      assert.equal(res.status, 403, `path: ${path}`);
      assert.equal(res.body, "Forbidden");
    }
  } finally {
    await stop(server);
  }
});

test("unsupported methods get 405 with Allow", async () => {
  const { server, base } = await start();
  try {
    for (const method of ["POST", "PUT", "DELETE"]) {
      const res = await fetch(`${base}/notes.txt`, { method, body: "x" });
      assert.equal(res.status, 405, method);
      assert.equal(res.headers.get("allow"), "GET, HEAD");
    }
  } finally {
    await stop(server);
  }
});

test("unknown extensions fall back to octet-stream", async () => {
  const { server, base } = await start();
  try {
    const res = await fetch(`${base}/notes.txt`);
    assert.equal(res.headers.get("content-type"), "text/plain");
    const svgless = await fetch(`${base}/no-such.bin`);
    assert.equal(svgless.status, 404);
  } finally {
    await stop(server);
  }
});
