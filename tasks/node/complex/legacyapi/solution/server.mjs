import http from "node:http";
import { Router } from "./router.mjs";
import { readJson } from "./body.mjs";
import { createStore } from "./store.mjs";
import { checkAuth } from "./auth.mjs";

function json(res, status, payload, headers = {}) {
  res.writeHead(status, { "Content-Type": "application/json", ...headers });
  res.end(JSON.stringify(payload));
}

function validateOrder(data) {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    return "body must be an object";
  }
  if (typeof data.customer !== "string" || data.customer.length === 0) {
    return "customer must be a non-empty string";
  }
  if (!Array.isArray(data.items) || data.items.length === 0) {
    return "items must be a non-empty array";
  }
  for (const item of data.items) {
    if (typeof item !== "object" || item === null) return "invalid item";
    if (typeof item.sku !== "string" || item.sku.length === 0) {
      return "invalid item sku";
    }
    if (!Number.isInteger(item.qty) || item.qty <= 0) {
      return "invalid item qty";
    }
  }
  return null;
}

function parsePagination(url) {
  const out = { limit: 20, offset: 0 };
  for (const key of ["limit", "offset"]) {
    const raw = url.searchParams.get(key);
    if (raw === null) continue;
    const n = Number(raw);
    if (!Number.isInteger(n) || n < 0) return null;
    out[key] = n;
  }
  return out;
}

export function createApp({ tokens = [] } = {}) {
  const store = createStore();
  const router = new Router();

  router.add("POST", "/orders", async (req, res) => {
    const data = await readJson(req);
    const problem = validateOrder(data);
    if (problem !== null) {
      return json(res, 400, { error: problem });
    }
    const order = store.insert({
      customer: data.customer,
      items: data.items,
      status: "pending",
    });
    json(res, 201, order);
  });

  router.add("GET", "/orders", async (req, res, params, url) => {
    const pagination = parsePagination(url);
    if (pagination === null) {
      return json(res, 400, { error: "invalid pagination" });
    }
    const status = url.searchParams.get("status");
    const filtered =
      status === null
        ? store.list()
        : store.list().filter((order) => order.status === status);
    const page = filtered.slice(
      pagination.offset,
      pagination.offset + pagination.limit,
    );
    json(res, 200, page, { "X-Total-Count": String(filtered.length) });
  });

  router.add("GET", "/orders/:id", async (req, res, params) => {
    const order = store.get(params.id);
    if (!order) return json(res, 404, { error: "not found" });
    json(res, 200, order);
  });

  router.add("POST", "/orders/:id/cancel", async (req, res, params) => {
    const order = store.get(params.id);
    if (!order) return json(res, 404, { error: "not found" });
    if (order.status !== "pending") {
      return json(res, 409, { error: "already cancelled" });
    }
    order.status = "cancelled";
    json(res, 200, order);
  });

  router.add("DELETE", "/orders/:id", async (req, res, params) => {
    if (!store.remove(params.id)) {
      return json(res, 404, { error: "not found" });
    }
    res.writeHead(204);
    res.end();
  });

  return http.createServer(async (req, res) => {
    try {
      if (!checkAuth(req, tokens)) {
        return json(res, 401, { error: "unauthorized" });
      }
      const url = new URL(req.url, "http://localhost");
      const match = router.match(req.method, url.pathname);
      if (!match) {
        // drain any body so keep-alive connections stay usable
        req.resume();
        return json(res, 404, { error: "not found" });
      }
      await match.handler(req, res, match.params, url);
    } catch (err) {
      const status = err?.statusCode ?? 500;
      if (!res.headersSent) {
        return json(res, status, {
          error: status === 400 ? err.message : "internal error",
        });
      }
      res.end();
    }
  });
}
