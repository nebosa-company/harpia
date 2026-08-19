/** Ledger reporting, narrowed end to end. */
export interface Sale {
  kind: "sale";
  amount: number;
  region: string;
}

export interface Refund {
  kind: "refund";
  amount: number;
  reason: string;
}

export interface Adjustment {
  kind: "adjustment";
  delta: number;
  note: string;
}

export type Entry = Sale | Refund | Adjustment;

export interface Summary {
  net: number;
  counts: { sale: number; refund: number; adjustment: number };
  regions: string[];
  skipped: number;
}

export function decode(line: string): Entry | null {
  const parts = line.split("|");
  if (parts.length !== 3) return null;
  const kind = parts[0];
  const value = Number(parts[1]);
  const text = (parts[2] ?? "").trim();
  if (!Number.isFinite(value) || text === "") return null;
  switch (kind) {
    case "sale":
      return { kind: "sale", amount: value, region: text };
    case "refund":
      return { kind: "refund", amount: value, reason: text };
    case "adjustment":
      return { kind: "adjustment", delta: value, note: text };
    default:
      return null;
  }
}

function unreachable(entry: never): never {
  throw new Error("unhandled entry: " + JSON.stringify(entry));
}

export function amountOf(entry: Entry): number {
  switch (entry.kind) {
    case "sale":
      return entry.amount;
    case "refund":
      return -entry.amount;
    case "adjustment":
      return entry.delta;
    default:
      return unreachable(entry);
  }
}

export function summarize(lines: readonly string[]): Summary {
  const counts = { sale: 0, refund: 0, adjustment: 0 };
  const regions = new Set<string>();
  let net = 0;
  let skipped = 0;
  for (const line of lines) {
    const entry = decode(line);
    if (entry === null) {
      skipped += 1;
      continue;
    }
    counts[entry.kind] += 1;
    if (entry.kind === "sale") {
      regions.add(entry.region);
    }
    net += amountOf(entry);
  }
  return {
    net: Math.round(net * 100) / 100,
    counts,
    regions: [...regions].sort(),
    skipped,
  };
}
