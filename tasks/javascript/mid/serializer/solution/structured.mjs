// Structured clone over JSON text.

export function encode(value) {
  const nodes = [];
  const seen = new Map();

  function slot(v) {
    if (v === undefined) return ["u"];
    if (v === null) return ["p", null];
    switch (typeof v) {
      case "string":
      case "boolean":
        return ["p", v];
      case "number":
        if (Number.isNaN(v)) return ["n", "NaN"];
        if (v === Infinity) return ["n", "Infinity"];
        if (v === -Infinity) return ["n", "-Infinity"];
        if (Object.is(v, -0)) return ["n", "-0"];
        return ["p", v];
      case "bigint":
        return ["b", v.toString()];
      case "function":
        throw new TypeError("encode: functions are not serializable");
      case "symbol":
        throw new TypeError("encode: symbols are not serializable");
      default:
        break;
    }
    if (seen.has(v)) return ["r", seen.get(v)];
    const at = nodes.length;
    nodes.push(null);
    seen.set(v, at);
    nodes[at] = build(v);
    return ["r", at];
  }

  function build(v) {
    if (v instanceof Date) return { t: "date", v: v.getTime() };
    if (v instanceof RegExp) return { t: "regexp", s: v.source, f: v.flags };
    if (v instanceof Map) {
      return { t: "map", e: [...v.entries()].map(([k, val]) => [slot(k), slot(val)]) };
    }
    if (v instanceof Set) return { t: "set", e: [...v.values()].map((x) => slot(x)) };
    if (Array.isArray(v)) return { t: "array", e: v.map((x) => slot(x)) };
    return { t: "object", e: Object.keys(v).map((k) => [k, slot(v[k])]) };
  }

  const root = slot(value);
  return JSON.stringify({ v: 1, root, nodes });
}

export function decode(text) {
  if (typeof text !== "string") {
    throw new TypeError("decode expects a string");
  }
  const payload = JSON.parse(text);
  if (payload === null || typeof payload !== "object" || !Array.isArray(payload.nodes) || !Array.isArray(payload.root)) {
    throw new TypeError("decode: not an encoded payload");
  }

  const shells = payload.nodes.map((node) => {
    switch (node.t) {
      case "object":
        return {};
      case "array":
        return [];
      case "map":
        return new Map();
      case "set":
        return new Set();
      case "date":
        return new Date(node.v);
      case "regexp":
        return new RegExp(node.s, node.f);
      default:
        throw new TypeError(`decode: unknown node type ${node.t}`);
    }
  });

  function value(s) {
    switch (s[0]) {
      case "p":
        return s[1];
      case "u":
        return undefined;
      case "n":
        if (s[1] === "NaN") return NaN;
        if (s[1] === "Infinity") return Infinity;
        if (s[1] === "-Infinity") return -Infinity;
        return -0;
      case "b":
        return BigInt(s[1]);
      case "r":
        return shells[s[1]];
      default:
        throw new TypeError("decode: unknown slot");
    }
  }

  payload.nodes.forEach((node, i) => {
    const target = shells[i];
    if (node.t === "object") {
      for (const [key, s] of node.e) target[key] = value(s);
    } else if (node.t === "array") {
      for (const s of node.e) target.push(value(s));
    } else if (node.t === "map") {
      for (const [k, v] of node.e) target.set(value(k), value(v));
    } else if (node.t === "set") {
      for (const s of node.e) target.add(value(s));
    }
  });

  return value(payload.root);
}
