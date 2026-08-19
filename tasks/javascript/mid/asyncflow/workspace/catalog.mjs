// Fixed dependency: the catalog service's error-first callback API.
// Do not change this file — other teams depend on this exact shape.

export function createCatalog(data) {
  let inFlight = 0;
  let peak = 0;
  let lookups = 0;

  return {
    lookup(name, cb) {
      if (typeof cb !== "function") {
        throw new TypeError("catalog.lookup requires a callback");
      }
      lookups += 1;
      inFlight += 1;
      if (inFlight > peak) peak = inFlight;
      queueMicrotask(() => {
        queueMicrotask(() => {
          inFlight -= 1;
          const entry = data[name];
          if (!entry) {
            const err = new Error(`unknown item: ${name}`);
            err.code = "NOT_FOUND";
            cb(err);
            return;
          }
          cb(null, { cost: entry.cost, parts: [...(entry.parts ?? [])] });
        });
      });
    },

    stats() {
      return { lookups, peak };
    },
  };
}
