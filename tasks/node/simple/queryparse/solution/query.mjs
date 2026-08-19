export function parseQuery(input) {
  if (typeof input !== "string") {
    throw new TypeError("parseQuery: input must be a string");
  }
  const s = input.startsWith("?") ? input.slice(1) : input;
  const out = Object.create(null);
  if (s === "") return out;
  for (const segment of s.split("&")) {
    if (segment === "") continue;
    const eq = segment.indexOf("=");
    const rawKey = eq === -1 ? segment : segment.slice(0, eq);
    const rawVal = eq === -1 ? "" : segment.slice(eq + 1);
    const key = decodeComponent(rawKey);
    const val = decodeComponent(rawVal);
    if (key in out) {
      if (Array.isArray(out[key])) out[key].push(val);
      else out[key] = [out[key], val];
    } else {
      out[key] = val;
    }
  }
  return out;
}

function decodeComponent(raw) {
  const plussed = raw.replace(/\+/g, " ");
  try {
    return decodeURIComponent(plussed);
  } catch {
    return plussed;
  }
}

export function formatQuery(params) {
  const parts = [];
  for (const [key, value] of Object.entries(params)) {
    const values = Array.isArray(value) ? value : [value];
    for (const v of values) {
      parts.push(`${encode(key)}=${encode(String(v))}`);
    }
  }
  return parts.join("&");
}

function encode(s) {
  return encodeURIComponent(s).replace(/%20/g, "+");
}
