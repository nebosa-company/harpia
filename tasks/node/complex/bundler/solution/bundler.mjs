// ESM bundler-lite: resolve the import graph, emit one self-contained module.

import { readFile } from "node:fs/promises";
import path from "node:path";

const IDENT = String.raw`[A-Za-z_$][\w$]*`;
const SIDE_EFFECT_RE = /^import\s*(['"])([^'"]+)\1\s*;?\s*$/;
const WITH_CLAUSE_RE = /^import\s+(.+?)\s+from\s*(['"])([^'"]+)\2\s*;?\s*$/;
const EXPORT_STAR_RE = /^export\s+\*/;
const EXPORT_FROM_RE = /^export\s*\{[^}]*\}\s*from\b/;
const EXPORT_LIST_RE = /^export\s*\{([^}]*)\}\s*;?\s*$/;
const EXPORT_DEFAULT_RE = /^export\s+default\s+/;
const EXPORT_DECL_RE = new RegExp(
  String.raw`^export\s+(?:(?:const|let|var)\s+(${IDENT})|(?:async\s+)?function\s*\*?\s*(${IDENT})|class\s+(${IDENT}))`,
);

function parseImportClause(clause, line) {
  if (clause.includes("*")) {
    throw new Error(`unsupported namespace import: ${line.trim()}`);
  }
  let defaultName = null;
  const named = [];
  const trimmed = clause.trim();
  const brace = trimmed.indexOf("{");
  if (brace === -1) {
    defaultName = trimmed;
    if (!new RegExp(`^${IDENT}$`).test(defaultName)) {
      throw new Error(`unsupported import clause: ${line.trim()}`);
    }
  } else {
    const before = trimmed.slice(0, brace).replace(/,\s*$/, "").trim();
    if (before !== "") {
      defaultName = before;
      if (!new RegExp(`^${IDENT}$`).test(defaultName)) {
        throw new Error(`unsupported import clause: ${line.trim()}`);
      }
    }
    const close = trimmed.indexOf("}");
    if (close === -1) {
      throw new Error(`unsupported import clause: ${line.trim()}`);
    }
    const inner = trimmed.slice(brace + 1, close);
    for (const item of inner.split(",")) {
      const part = item.trim();
      if (part === "") continue;
      const m = new RegExp(`^(${IDENT})(?:\\s+as\\s+(${IDENT}))?$`).exec(part);
      if (!m) throw new Error(`unsupported import clause: ${line.trim()}`);
      named.push({ imported: m[1], local: m[2] ?? m[1] });
    }
  }
  return { defaultName, named };
}

function parseModule(source) {
  const lines = source.split("\n");
  const imports = []; // { specifier, defaultName, named, lineIndex }
  const body = []; // strings, with import lines replaced by placeholders
  const exportsMap = new Map(); // exported name -> local name
  let hasDefault = false;

  for (const line of lines) {
    const t = line.trimEnd();

    if (EXPORT_STAR_RE.test(t) || EXPORT_FROM_RE.test(t)) {
      throw new Error(`unsupported re-export: ${t.trim()}`);
    }

    const side = SIDE_EFFECT_RE.exec(t);
    if (side) {
      imports.push({ specifier: side[2], defaultName: null, named: [], slot: body.length });
      body.push(null);
      continue;
    }

    const withClause = WITH_CLAUSE_RE.exec(t);
    if (withClause) {
      const { defaultName, named } = parseImportClause(withClause[1], t);
      imports.push({ specifier: withClause[3], defaultName, named, slot: body.length });
      body.push(null);
      continue;
    }

    if (/^import\b/.test(t)) {
      throw new Error(`unsupported import form: ${t.trim()}`);
    }

    const list = EXPORT_LIST_RE.exec(t);
    if (list) {
      for (const item of list[1].split(",")) {
        const part = item.trim();
        if (part === "") continue;
        const m = new RegExp(`^(${IDENT})(?:\\s+as\\s+(${IDENT}))?$`).exec(part);
        if (!m) throw new Error(`unsupported export list: ${t.trim()}`);
        exportsMap.set(m[2] ?? m[1], m[1]);
      }
      body.push("");
      continue;
    }

    if (EXPORT_DEFAULT_RE.test(t)) {
      if (hasDefault) throw new Error("unsupported: multiple default exports");
      hasDefault = true;
      exportsMap.set("default", "__default");
      body.push(t.replace(EXPORT_DEFAULT_RE, "const __default = "));
      continue;
    }

    const decl = EXPORT_DECL_RE.exec(t);
    if (decl) {
      const name = decl[1] ?? decl[2] ?? decl[3];
      exportsMap.set(name, name);
      body.push(t.replace(/^export\s+/, ""));
      continue;
    }

    body.push(line);
  }

  return { imports, body, exportsMap };
}

export async function bundle(entryPath) {
  const entryAbs = path.resolve(entryPath);
  const entryDir = path.dirname(entryAbs);
  const modules = new Map(); // abs path -> { id, exportsMap }
  const chunks = [];
  const visiting = new Set();
  const stack = [];

  const relLabel = (abs) =>
    path.relative(entryDir, abs).split(path.sep).join("/") || path.basename(abs);

  async function visit(abs, specifier, importer) {
    if (modules.has(abs)) return modules.get(abs);
    if (visiting.has(abs)) {
      const from = stack.indexOf(abs);
      const chain = [...stack.slice(from), abs].map(relLabel).join(" -> ");
      throw new Error(`import cycle detected: ${chain}`);
    }

    let source;
    try {
      source = await readFile(abs, "utf8");
    } catch {
      if (importer) {
        throw new Error(
          `cannot resolve '${specifier}' imported from '${relLabel(importer)}'`,
        );
      }
      throw new Error(`cannot read entry module '${entryPath}'`);
    }

    visiting.add(abs);
    stack.push(abs);

    const { imports, body, exportsMap } = parseModule(source);

    for (const imp of imports) {
      if (!imp.specifier.startsWith("./") && !imp.specifier.startsWith("../")) {
        throw new Error(`unsupported specifier '${imp.specifier}' in ${relLabel(abs)}`);
      }
      const childAbs = path.resolve(path.dirname(abs), imp.specifier);
      const child = await visit(childAbs, imp.specifier, abs);
      const bindings = [];
      if (imp.defaultName) {
        bindings.push(`const ${imp.defaultName} = __m${child.id}.default;`);
      }
      if (imp.named.length > 0) {
        const inner = imp.named
          .map((n) => (n.imported === n.local ? n.imported : `${n.imported}: ${n.local}`))
          .join(", ");
        bindings.push(`const { ${inner} } = __m${child.id};`);
      }
      body[imp.slot] = bindings.join("\n");
    }

    stack.pop();
    visiting.delete(abs);

    const id = chunks.length;
    const record = { id, exportsMap };
    modules.set(abs, record);

    const returns = [...exportsMap.entries()]
      .map(([exported, local]) =>
        exported === local ? exported : `${JSON.stringify(exported)}: ${local}`,
      )
      .join(", ");
    const bodyText = body.filter((l) => l !== null).join("\n");
    chunks.push(
      `// module: ${relLabel(abs)}\n` +
        `const __m${id} = (() => {\n${bodyText}\nreturn { ${returns} };\n})();`,
    );
    return record;
  }

  const entry = await visit(entryAbs, null, null);

  const footer = [];
  for (const exported of entry.exportsMap.keys()) {
    if (exported === "default") {
      footer.push(`export default __m${entry.id}.default;`);
    } else {
      footer.push(`export const ${exported} = __m${entry.id}.${exported};`);
    }
  }

  return `${chunks.join("\n\n")}\n\n${footer.join("\n")}\n`;
}
