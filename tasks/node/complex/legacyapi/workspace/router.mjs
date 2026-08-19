// Tiny method + path router. Patterns use :name segments, e.g.
// "/orders/:id/cancel". First registered match wins.

export class Router {
  #routes = [];

  add(method, pattern, handler) {
    this.#routes.push({
      method,
      segments: pattern.split("/").filter(Boolean),
      handler,
    });
  }

  match(method, pathname) {
    const pathSegments = pathname.split("/").filter(Boolean);
    for (const route of this.#routes) {
      if (route.method !== method) continue;
      const params = {};
      let ok = true;
      for (let i = 0; i < route.segments.length; i++) {
        const want = route.segments[i];
        const got = pathSegments[i];
        if (want.startsWith(":")) {
          if (got === undefined) {
            ok = false;
            break;
          }
          params[want.slice(1)] = decodeURIComponent(got);
        } else if (want !== got) {
          ok = false;
          break;
        }
      }
      if (ok) {
        return { handler: route.handler, params };
      }
    }
    return null;
  }
}
