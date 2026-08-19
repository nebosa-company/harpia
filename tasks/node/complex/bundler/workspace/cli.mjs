import { writeFile } from "node:fs/promises";
import { bundle } from "./bundler.mjs";

const [entry, out] = process.argv.slice(2);
if (!entry || !out) {
  console.error("usage: node cli.mjs <entry> <out>");
  process.exit(2);
}

try {
  const code = await bundle(entry);
  await writeFile(out, code);
} catch (err) {
  console.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
}
