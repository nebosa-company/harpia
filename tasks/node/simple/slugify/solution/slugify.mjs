export function slugify(input, options = {}) {
  if (typeof input !== "string") {
    throw new TypeError("slugify: input must be a string");
  }
  const { separator = "-", maxLength = Infinity } = options;
  let s = input.replace(/&/g, " and ");
  s = s.normalize("NFKD").replace(/\p{M}/gu, "");
  s = s.toLowerCase();
  const parts = s.split(/[^a-z0-9]+/).filter(Boolean);
  let out = parts.join(separator);
  if (out.length > maxLength) {
    out = out.slice(0, maxLength);
    if (separator.length > 0) {
      while (out.endsWith(separator)) {
        out = out.slice(0, out.length - separator.length);
      }
    }
  }
  return out;
}
