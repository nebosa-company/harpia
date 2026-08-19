// Descriptor-preserving mixin composition.

export function mixin(target, ...sources) {
  if (target === null || (typeof target !== "object" && typeof target !== "function")) {
    throw new TypeError("mixin: target must be an object");
  }
  for (const source of sources) {
    if (source === null || source === undefined) continue;
    for (const key of Reflect.ownKeys(source)) {
      if (key === "constructor") continue;
      const desc = Object.getOwnPropertyDescriptor(source, key);
      Object.defineProperty(target, key, desc);
    }
  }
  return target;
}

export function layered(base, ...mixins) {
  let proto = base;
  for (const m of mixins) {
    proto = mixin(Object.create(proto), m);
  }
  return Object.create(proto);
}

export function chainOf(obj) {
  const chain = [];
  let cur = obj === null || obj === undefined ? null : Object.getPrototypeOf(obj);
  while (cur !== null) {
    chain.push(cur);
    cur = Object.getPrototypeOf(cur);
  }
  return chain;
}

export function classWith(Base, ...mixins) {
  const Mixed = class extends Base {};
  mixin(Mixed.prototype, ...mixins);
  return Mixed;
}
