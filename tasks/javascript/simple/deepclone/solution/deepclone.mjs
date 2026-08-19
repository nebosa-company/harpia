// deepClone(value) -> structural copy that survives cycles.

export function deepClone(value) {
  return clone(value, new Map());
}

function clone(value, seen) {
  if (value === null || (typeof value !== "object" && typeof value !== "function")) {
    return value;
  }
  if (typeof value === "function") return value;
  if (seen.has(value)) return seen.get(value);

  if (value instanceof Date) {
    const copy = new Date(value.getTime());
    seen.set(value, copy);
    return copy;
  }
  if (value instanceof RegExp) {
    const copy = new RegExp(value.source, value.flags);
    copy.lastIndex = value.lastIndex;
    seen.set(value, copy);
    return copy;
  }
  if (value instanceof Map) {
    const copy = new Map();
    seen.set(value, copy);
    for (const [k, v] of value) copy.set(clone(k, seen), clone(v, seen));
    return copy;
  }
  if (value instanceof Set) {
    const copy = new Set();
    seen.set(value, copy);
    for (const v of value) copy.add(clone(v, seen));
    return copy;
  }
  if (Array.isArray(value)) {
    const copy = [];
    seen.set(value, copy);
    for (let i = 0; i < value.length; i++) copy[i] = clone(value[i], seen);
    return copy;
  }

  const copy = Object.create(Object.getPrototypeOf(value));
  seen.set(value, copy);
  for (const key of Reflect.ownKeys(value)) {
    const desc = Object.getOwnPropertyDescriptor(value, key);
    if (!desc.enumerable) continue;
    const raw = "get" in desc || "set" in desc ? value[key] : desc.value;
    Object.defineProperty(copy, key, {
      value: clone(raw, seen),
      writable: true,
      enumerable: true,
      configurable: true,
    });
  }
  return copy;
}
