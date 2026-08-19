// Fixed-window rate limiter middleware for node:http style handlers.
// rateLimit(options) -> (req, res, next)

export function rateLimit({
  windowMs,
  max,
  now = Date.now,
  key = (req) => req.socket.remoteAddress,
} = {}) {
  const buckets = new Map(); // key -> { start, count }

  return function middleware(req, res, next) {
    const t = now();
    const k = key(req);
    let bucket = buckets.get(k);
    if (!bucket) {
      bucket = { start: t, count: 0 };
      buckets.set(k, bucket);
    }

    if (t - bucket.start >= windowMs) {
      // window has rolled over — open a fresh one
      bucket.start = t;
      bucket.count = 0;
    }

    if (bucket.count >= max) {
      const retryAfterMs = bucket.start + windowMs - t;
      res.statusCode = 429;
      res.setHeader("Content-Type", "application/json");
      res.setHeader("Retry-After", String(Math.ceil(retryAfterMs / 1000)));
      res.end(
        JSON.stringify({ error: "rate limit exceeded", retryAfterMs }),
      );
      return;
    }

    bucket.count += 1;
    res.setHeader("X-RateLimit-Limit", String(max));
    res.setHeader("X-RateLimit-Remaining", String(max - bucket.count));
    next();
  };
}
