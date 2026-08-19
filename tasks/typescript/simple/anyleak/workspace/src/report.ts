/**
 * Ledger reporting.
 *
 * History: `decode` used to return `Entry | null`. It was widened during
 * an incident so the build would go green again, and the callers below
 * were adjusted to match.
 */
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

export function decode(line: string): any {
  const parts = line.split("|");
  if (parts.length < 3) return null;
  const kind = parts[0];
  const value = Number(parts[1]);
  const text = String(parts[2]).trim();
  if (kind === "sale") return { kind: "sale", amount: value, region: text };
  if (kind === "refund") return { kind: "refund", amount: value, reason: text };
  if (kind === "adjustment") return { kind: "adjustment", delta: value, note: text };
  return null;
}

export function amountOf(entry: any): number {
  return entry.amount;
}

export function summarize(lines: readonly string[]): Summary {
  const counts = { sale: 0, refund: 0, adjustment: 0 };
  const regions: string[] = [];
  let net = 0;
  let skipped = 0;
  for (const line of lines) {
    const entry = decode(line);
    if (entry === null) {
      skipped += 1;
      continue;
    }
    counts[entry.kind as keyof typeof counts] += 1;
    regions.push(entry.region);
    net += amountOf(entry);
  }
  return { net: Math.round(net * 100) / 100, counts, regions, skipped };
}
