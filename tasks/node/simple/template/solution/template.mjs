const IDENT_RE = /^[A-Za-z_$][A-Za-z0-9_$]*$/;
const INDEX_RE = /^\d+$/;

export function render(template, data, options = {}) {
  if (typeof template !== "string") {
    throw new TypeError("render: template must be a string");
  }
  const { onMissing = "empty" } = options;
  let out = "";
  let i = 0;
  while (i < template.length) {
    if (template[i] === "\\" && template.startsWith("{{", i + 1)) {
      out += "{{";
      i += 3;
      continue;
    }
    if (template.startsWith("{{", i)) {
      const close = template.indexOf("}}", i + 2);
      if (close === -1) {
        throw new Error(`unclosed placeholder at index ${i}`);
      }
      const raw = template.slice(i + 2, close);
      const path = raw.trim();
      const segments = path.split(".");
      const valid =
        path.length > 0 &&
        segments.every((s) => IDENT_RE.test(s) || INDEX_RE.test(s));
      if (!valid) {
        throw new Error(`invalid placeholder: {{${raw}}}`);
      }
      let value = data;
      let missing = false;
      for (const seg of segments) {
        if (value === null || typeof value !== "object" || !(seg in value)) {
          missing = true;
          break;
        }
        value = value[seg];
      }
      if (!missing && (value === undefined || value === null)) {
        missing = true;
      }
      if (missing) {
        if (onMissing === "error") {
          throw new Error(`missing value for path: ${path}`);
        }
        if (onMissing === "keep") {
          out += template.slice(i, close + 2);
        }
        // "empty": emit nothing
      } else {
        out += stringify(value);
      }
      i = close + 2;
      continue;
    }
    out += template[i];
    i += 1;
  }
  return out;
}

function stringify(value) {
  if (typeof value === "string") return value;
  if (typeof value === "object") return JSON.stringify(value);
  return String(value);
}
