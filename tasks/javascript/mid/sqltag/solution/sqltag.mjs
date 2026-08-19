// Parameterized SQL construction via tagged templates.

const FRAGMENT = Symbol("sql.fragment");

function makeFragment(chunks, values) {
  const frag = { chunks, values };
  Object.defineProperty(frag, FRAGMENT, { value: true });
  Object.defineProperty(frag, "text", {
    enumerable: true,
    get() {
      let out = "";
      for (let i = 0; i < frag.chunks.length; i++) {
        out += frag.chunks[i];
        if (i < frag.values.length) out += `$${i + 1}`;
      }
      return out;
    },
  });
  return frag;
}

function isFragment(value) {
  return value !== null && typeof value === "object" && value[FRAGMENT] === true;
}

function checkValue(value) {
  if (value === undefined) throw new TypeError("undefined is not a valid SQL value");
  if (typeof value === "function") throw new TypeError("a function is not a valid SQL value");
  if (typeof value === "symbol") throw new TypeError("a symbol is not a valid SQL value");
}

function createBuilder() {
  const chunks = [""];
  const values = [];
  const addText = (text) => {
    chunks[chunks.length - 1] += text;
  };
  const addValue = (value) => {
    values.push(value);
    chunks.push("");
  };
  const addFragment = (frag) => {
    addText(frag.chunks[0]);
    for (let i = 0; i < frag.values.length; i++) {
      addValue(frag.values[i]);
      addText(frag.chunks[i + 1]);
    }
  };
  const addAny = (value) => {
    if (isFragment(value)) {
      addFragment(value);
      return;
    }
    if (Array.isArray(value)) {
      if (value.length === 0) {
        throw new RangeError("an empty array has no placeholder expansion");
      }
      value.forEach((entry, i) => {
        if (i > 0) addText(", ");
        addAny(entry);
      });
      return;
    }
    checkValue(value);
    addValue(value);
  };
  return { addText, addAny, finish: () => makeFragment(chunks, values) };
}

export function sql(strings, ...values) {
  if (!Array.isArray(strings) || !Array.isArray(strings.raw)) {
    throw new TypeError("sql must be used as a template tag");
  }
  const builder = createBuilder();
  strings.forEach((chunk, i) => {
    builder.addText(chunk);
    if (i < values.length) builder.addAny(values[i]);
  });
  return builder.finish();
}

export function ident(name) {
  if (typeof name !== "string" || name.length === 0) {
    throw new TypeError("ident expects a non-empty string");
  }
  return makeFragment([`"${name.replaceAll('"', '""')}"`], []);
}

export function raw(text) {
  if (typeof text !== "string") throw new TypeError("raw expects a string");
  return makeFragment([text], []);
}

export function join(entries, separator = ", ") {
  if (!Array.isArray(entries)) throw new TypeError("join expects an array");
  if (typeof separator !== "string") throw new TypeError("separator must be a string");
  const builder = createBuilder();
  entries.forEach((entry, i) => {
    if (i > 0) builder.addText(separator);
    builder.addAny(entry);
  });
  return builder.finish();
}

export function escapeLiteral(value) {
  if (value === null) return "NULL";
  if (typeof value === "string") return `'${value.replaceAll("'", "''")}'`;
  if (typeof value === "boolean") return value ? "TRUE" : "FALSE";
  if (typeof value === "bigint") return value.toString();
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new TypeError("only finite numbers have SQL literals");
    return String(value);
  }
  if (value instanceof Date) return `'${value.toISOString()}'`;
  throw new TypeError(`no SQL literal for ${typeof value}`);
}
