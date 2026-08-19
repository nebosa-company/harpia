const CORE_RE = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const ID_RE = /^[0-9A-Za-z-]+$/;
const NUM_RE = /^(0|[1-9]\d*)$/;

function invalid(v) {
  return new Error(`invalid version: ${String(v)}`);
}

export function parseVersion(v) {
  if (typeof v !== "string") throw invalid(v);
  let s = v;
  if (s.startsWith("v")) s = s.slice(1);

  let build = [];
  const plus = s.indexOf("+");
  if (plus !== -1) {
    const raw = s.slice(plus + 1);
    s = s.slice(0, plus);
    if (raw === "") throw invalid(v);
    build = raw.split(".");
    for (const id of build) {
      if (id === "" || !ID_RE.test(id)) throw invalid(v);
    }
  }

  let prerelease = [];
  const dash = s.indexOf("-");
  if (dash !== -1) {
    const raw = s.slice(dash + 1);
    s = s.slice(0, dash);
    if (raw === "") throw invalid(v);
    prerelease = raw.split(".").map((id) => {
      if (id === "" || !ID_RE.test(id)) throw invalid(v);
      if (/^\d+$/.test(id)) {
        if (!NUM_RE.test(id)) throw invalid(v); // leading zeros
        return Number(id);
      }
      return id;
    });
  }

  const m = CORE_RE.exec(s);
  if (!m) throw invalid(v);
  return {
    major: Number(m[1]),
    minor: Number(m[2]),
    patch: Number(m[3]),
    prerelease,
    build,
  };
}

function comparePrerelease(a, b) {
  if (a.length === 0 && b.length === 0) return 0;
  if (a.length === 0) return 1; // release > prerelease
  if (b.length === 0) return -1;
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) {
    const x = a[i];
    const y = b[i];
    if (x === y) continue;
    const xNum = typeof x === "number";
    const yNum = typeof y === "number";
    if (xNum && yNum) return x < y ? -1 : 1;
    if (xNum) return -1; // numeric < alphanumeric
    if (yNum) return 1;
    return x < y ? -1 : 1;
  }
  if (a.length === b.length) return 0;
  return a.length < b.length ? -1 : 1;
}

export function compareVersions(a, b) {
  const pa = parseVersion(a);
  const pb = parseVersion(b);
  for (const key of ["major", "minor", "patch"]) {
    if (pa[key] !== pb[key]) return pa[key] < pb[key] ? -1 : 1;
  }
  return comparePrerelease(pa.prerelease, pb.prerelease);
}

export function sortVersions(list) {
  return [...list].sort((a, b) => compareVersions(a, b));
}
