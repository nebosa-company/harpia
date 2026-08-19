import http from "node:http";
import path from "node:path";
import { createHash } from "node:crypto";
import { readFile, stat } from "node:fs/promises";

const TYPES = {
  html: "text/html",
  css: "text/css",
  js: "text/javascript",
  json: "application/json",
  txt: "text/plain",
  png: "image/png",
  svg: "image/svg+xml",
};

export function createStaticServer(rootDir) {
  const root = path.resolve(rootDir);

  return http.createServer(async (req, res) => {
    const plain = (status, body, headers = {}) => {
      res.writeHead(status, { "Content-Type": "text/plain", ...headers });
      res.end(req.method === "HEAD" ? undefined : body);
    };

    try {
      if (req.method !== "GET" && req.method !== "HEAD") {
        res.writeHead(405, { Allow: "GET, HEAD", "Content-Type": "text/plain" });
        return res.end("Method Not Allowed");
      }

      // Use the raw request path: new URL() would collapse dot segments
      // before we get a chance to reject them.
      const rawPath = (req.url ?? "/").split("?")[0];
      let pathname;
      try {
        pathname = decodeURIComponent(rawPath);
      } catch {
        return plain(400, "Bad Request");
      }

      const segments = pathname.split(/[/\\]+/);
      if (segments.includes("..")) {
        return plain(403, "Forbidden");
      }

      const parts = segments.filter(Boolean);
      const filePath =
        parts.length === 0
          ? path.join(root, "index.html")
          : path.join(root, ...parts);

      let data;
      try {
        const info = await stat(filePath);
        if (info.isDirectory()) return plain(404, "Not Found");
        data = await readFile(filePath);
      } catch {
        return plain(404, "Not Found");
      }

      const etag = `"${createHash("sha1").update(data).digest("hex")}"`;
      const ext = path.extname(filePath).slice(1).toLowerCase();
      const type = TYPES[ext] ?? "application/octet-stream";

      const inm = req.headers["if-none-match"];
      if (inm !== undefined) {
        const tags = inm.split(",").map((t) => t.trim());
        if (tags.includes("*") || tags.includes(etag)) {
          res.writeHead(304, { ETag: etag });
          return res.end();
        }
      }

      const size = data.length;
      const range = parseRange(req.headers.range, size);
      if (range === "unsatisfiable") {
        res.writeHead(416, { "Content-Range": `bytes */${size}` });
        return res.end();
      }

      const common = {
        "Content-Type": type,
        ETag: etag,
        "Accept-Ranges": "bytes",
      };

      if (range) {
        const { start, end } = range;
        res.writeHead(206, {
          ...common,
          "Content-Range": `bytes ${start}-${end}/${size}`,
          "Content-Length": String(end - start + 1),
        });
        return res.end(
          req.method === "HEAD" ? undefined : data.subarray(start, end + 1),
        );
      }

      res.writeHead(200, { ...common, "Content-Length": String(size) });
      return res.end(req.method === "HEAD" ? undefined : data);
    } catch {
      if (!res.headersSent) {
        res.writeHead(500, { "Content-Type": "text/plain" });
      }
      res.end();
    }
  });
}

function parseRange(header, size) {
  if (!header) return null;
  const m = /^bytes=(\d*)-(\d*)$/.exec(header.trim());
  if (!m) return null; // malformed or multiple ranges: ignore
  const [, a, b] = m;
  if (a === "" && b === "") return null;

  if (a === "") {
    // suffix form: last n bytes
    const n = Number(b);
    if (n === 0 || size === 0) return "unsatisfiable";
    return { start: Math.max(0, size - n), end: size - 1 };
  }

  const start = Number(a);
  if (start >= size) return "unsatisfiable";
  const end = b === "" ? size - 1 : Math.min(Number(b), size - 1);
  if (end < start) return null; // syntactically invalid: ignore
  return { start, end };
}
