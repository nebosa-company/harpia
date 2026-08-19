const TABLE = {
  html: "text/html",
  htm: "text/html",
  css: "text/css",
  js: "text/javascript",
  mjs: "text/javascript",
  json: "application/json",
  txt: "text/plain",
  md: "text/markdown",
  csv: "text/csv",
  xml: "application/xml",
  svg: "image/svg+xml",
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  gif: "image/gif",
  ico: "image/x-icon",
  webp: "image/webp",
  woff: "font/woff",
  woff2: "font/woff2",
  mp3: "audio/mpeg",
  mp4: "video/mp4",
  wasm: "application/wasm",
  pdf: "application/pdf",
  zip: "application/zip",
  gz: "application/gzip",
};

const FALLBACK = "application/octet-stream";

export function extensionOf(p) {
  let s = String(p);
  for (const stop of ["?", "#"]) {
    const at = s.indexOf(stop);
    if (at !== -1) s = s.slice(0, at);
  }
  const lastSep = Math.max(s.lastIndexOf("/"), s.lastIndexOf("\\"));
  const base = s.slice(lastSep + 1);
  const dot = base.lastIndexOf(".");
  if (dot <= 0) return "";
  return base.slice(dot + 1).toLowerCase();
}

export function lookup(pathOrExt) {
  const s = String(pathOrExt);
  const looksLikePath =
    s.includes("/") || s.includes("\\") || s.slice(1).includes(".");
  const ext = looksLikePath
    ? extensionOf(s)
    : (s.startsWith(".") ? s.slice(1) : s).toLowerCase();
  return TABLE[ext] ?? FALLBACK;
}

const TEXTUAL = new Set(["application/json", "application/xml", "image/svg+xml"]);

export function contentTypeFor(p) {
  const type = lookup(p);
  if (type.startsWith("text/") || TEXTUAL.has(type)) {
    return `${type}; charset=utf-8`;
  }
  return type;
}
