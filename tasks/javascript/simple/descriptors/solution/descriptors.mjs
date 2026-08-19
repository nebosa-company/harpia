// Descriptor-level object utilities.

function requireObject(obj, who) {
  if (obj === null || (typeof obj !== "object" && typeof obj !== "function")) {
    throw new TypeError(`${who} expects an object`);
  }
}

export function audit(obj) {
  requireObject(obj, "audit");
  return Reflect.ownKeys(obj).map((key) => {
    const desc = Object.getOwnPropertyDescriptor(obj, key);
    const accessor = "get" in desc || "set" in desc;
    return {
      key,
      kind: accessor ? "accessor" : "data",
      enumerable: desc.enumerable,
      configurable: desc.configurable,
      writable: accessor ? null : desc.writable,
      hasGetter: accessor ? typeof desc.get === "function" : false,
      hasSetter: accessor ? typeof desc.set === "function" : false,
    };
  });
}

export function sealValues(obj, keys) {
  requireObject(obj, "sealValues");
  const list = [...keys];
  const descs = list.map((key) => {
    const desc = Object.getOwnPropertyDescriptor(obj, key);
    if (!desc) throw new TypeError(`sealValues: no own property ${String(key)}`);
    if ("get" in desc || "set" in desc) {
      throw new TypeError(`sealValues: ${String(key)} is an accessor`);
    }
    return desc;
  });
  list.forEach((key, i) => {
    Object.defineProperty(obj, key, {
      value: descs[i].value,
      enumerable: descs[i].enumerable,
      writable: false,
      configurable: false,
    });
  });
  return obj;
}

export function mirror(source, target, keys) {
  requireObject(source, "mirror");
  requireObject(target, "mirror");
  for (const key of keys) {
    Object.defineProperty(target, key, {
      get() {
        return source[key];
      },
      set(value) {
        source[key] = value;
      },
      enumerable: true,
      configurable: true,
    });
  }
  return target;
}

export function stripAccessors(obj) {
  requireObject(obj, "stripAccessors");
  const out = Object.create(Object.getPrototypeOf(obj));
  for (const key of Reflect.ownKeys(obj)) {
    const desc = Object.getOwnPropertyDescriptor(obj, key);
    const accessor = "get" in desc || "set" in desc;
    const value = accessor ? (desc.get ? desc.get.call(obj) : undefined) : desc.value;
    Object.defineProperty(out, key, {
      value,
      writable: true,
      enumerable: desc.enumerable,
      configurable: true,
    });
  }
  return out;
}
