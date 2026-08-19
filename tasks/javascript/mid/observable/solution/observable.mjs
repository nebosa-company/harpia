// Deep Proxy observable with path subscriptions.

const RAW = Symbol("observable.raw");
const STATE = Symbol("observable.state");

function isWrappable(value) {
  if (value === null || typeof value !== "object") return false;
  if (Array.isArray(value)) return true;
  const proto = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

function joinPath(base, key) {
  return base === "" ? String(key) : `${base}.${String(key)}`;
}

function ancestors(path) {
  const chain = [path];
  let current = path;
  while (current !== "") {
    const cut = current.lastIndexOf(".");
    current = cut === -1 ? "" : current.slice(0, cut);
    chain.push(current);
  }
  return chain;
}

function unwrap(value) {
  return value !== null && typeof value === "object" && value[RAW] ? value[RAW] : value;
}

function notify(state, record) {
  const targets = [];
  for (const path of ancestors(record.path)) {
    const list = state.listeners.get(path);
    if (list) targets.push(...list);
  }
  for (const listener of targets) listener(record);
}

function wrap(target, path, state) {
  const cached = state.proxies.get(target);
  if (cached) return cached;

  const proxy = new Proxy(target, {
    get(t, key, receiver) {
      if (key === RAW) return t;
      if (key === STATE) return state;
      const value = Reflect.get(t, key, receiver);
      if (typeof key === "symbol") return value;
      if (isWrappable(value)) return wrap(value, joinPath(path, key), state);
      return value;
    },
    set(t, key, value) {
      if (typeof key === "symbol") return Reflect.set(t, key, value);
      const had = Object.hasOwn(t, key);
      const previous = had ? t[key] : undefined;
      const next = unwrap(value);
      const ok = Reflect.set(t, key, next);
      if (!ok) return false;
      if (!had || !Object.is(previous, next)) {
        notify(state, {
          path: joinPath(path, key),
          kind: "set",
          value: next,
          previous,
        });
      }
      return true;
    },
    deleteProperty(t, key) {
      if (typeof key === "symbol") return Reflect.deleteProperty(t, key);
      const had = Object.hasOwn(t, key);
      const previous = had ? t[key] : undefined;
      const ok = Reflect.deleteProperty(t, key);
      if (ok && had) {
        notify(state, {
          path: joinPath(path, key),
          kind: "delete",
          value: undefined,
          previous,
        });
      }
      return ok;
    },
  });

  state.proxies.set(target, proxy);
  return proxy;
}

export function observable(target) {
  if (!isWrappable(target)) {
    throw new TypeError("observable expects a plain object or an array");
  }
  const state = { listeners: new Map(), proxies: new WeakMap() };
  return wrap(target, "", state);
}

export function subscribe(proxy, path, listener) {
  const state = proxy !== null && typeof proxy === "object" ? proxy[STATE] : undefined;
  if (!state) throw new TypeError("subscribe expects an observable");
  if (typeof path !== "string") throw new TypeError("path must be a string");
  if (typeof listener !== "function") throw new TypeError("listener must be a function");
  let list = state.listeners.get(path);
  if (!list) {
    list = [];
    state.listeners.set(path, list);
  }
  list.push(listener);
  return () => {
    const i = list.indexOf(listener);
    if (i === -1) return false;
    list.splice(i, 1);
    return true;
  };
}

export function raw(proxy) {
  const target = proxy !== null && typeof proxy === "object" ? proxy[RAW] : undefined;
  if (!target) throw new TypeError("raw expects an observable");
  return target;
}
