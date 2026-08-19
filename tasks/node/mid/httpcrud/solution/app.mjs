import http from "node:http";

export function createApp() {
  const notes = new Map(); // id -> note
  let nextId = 1;

  return http.createServer(async (req, res) => {
    const url = new URL(req.url, "http://localhost");
    const segments = url.pathname.split("/").filter(Boolean);

    const json = (status, payload, headers = {}) => {
      res.writeHead(status, {
        "Content-Type": "application/json",
        ...headers,
      });
      res.end(JSON.stringify(payload));
    };

    try {
      if (segments.length === 1 && segments[0] === "notes") {
        if (req.method === "GET") {
          return json(200, [...notes.values()]);
        }
        if (req.method === "POST") {
          const parsed = await readNote(req);
          if (parsed.error) return json(400, { error: parsed.error });
          const id = String(nextId++);
          const note = { id, ...parsed.value };
          notes.set(id, note);
          return json(201, note, { Location: `/notes/${id}` });
        }
        res.writeHead(405, {
          "Content-Type": "application/json",
          Allow: "GET, POST",
        });
        return res.end(JSON.stringify({ error: "method not allowed" }));
      }

      if (segments.length === 2 && segments[0] === "notes") {
        const id = decodeURIComponent(segments[1]);
        if (req.method === "GET") {
          const note = notes.get(id);
          if (!note) return json(404, { error: "not found" });
          return json(200, note);
        }
        if (req.method === "PUT") {
          if (!notes.has(id)) {
            // drain the body so the connection can be reused
            await readBody(req);
            return json(404, { error: "not found" });
          }
          const parsed = await readNote(req);
          if (parsed.error) return json(400, { error: parsed.error });
          const note = { id, ...parsed.value };
          notes.set(id, note);
          return json(200, note);
        }
        if (req.method === "DELETE") {
          if (!notes.delete(id)) return json(404, { error: "not found" });
          res.writeHead(204);
          return res.end();
        }
        res.writeHead(405, {
          "Content-Type": "application/json",
          Allow: "GET, PUT, DELETE",
        });
        return res.end(JSON.stringify({ error: "method not allowed" }));
      }

      return json(404, { error: "not found" });
    } catch {
      if (!res.headersSent) {
        return json(500, { error: "internal error" });
      }
      res.end();
    }
  });
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

async function readNote(req) {
  const raw = await readBody(req);
  let data;
  try {
    data = JSON.parse(raw);
  } catch {
    return { error: "invalid json" };
  }
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    return { error: "body must be a JSON object" };
  }
  if (typeof data.title !== "string" || data.title.length === 0) {
    return { error: "title must be a non-empty string" };
  }
  const body = data.body === undefined ? "" : data.body;
  if (typeof body !== "string") {
    return { error: "body must be a string" };
  }
  const tags = data.tags === undefined ? [] : data.tags;
  if (!Array.isArray(tags) || !tags.every((t) => typeof t === "string")) {
    return { error: "tags must be an array of strings" };
  }
  return { value: { title: data.title, body, tags } };
}
