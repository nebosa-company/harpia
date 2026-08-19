/** The order pipeline, plus the receipt. */
import { priceLine } from "./pricing";
import type { OrderLine, PricedLine } from "./pricing";

export type Adjustment =
  | { kind: "credit"; cents: number }
  | { kind: "fee"; cents: number; reason: string }
  | { kind: "tax"; rate: number };

export interface Order {
  id: string;
  items: OrderLine[];
  adjustments: Adjustment[];
}

export interface PricedOrder {
  id: string;
  lines: PricedLine[];
  rejected: string[];
  adjustments: Adjustment[];
  subtotalCents: number;
  adjustmentCents: number;
  totalCents: number;
}

export function assertNever(value: never): never {
  throw new Error("unhandled adjustment: " + JSON.stringify(value));
}

export function adjustmentValue(adjustment: Adjustment, subtotalCents: number): number {
  switch (adjustment.kind) {
    case "credit":
      return -adjustment.cents;
    case "fee":
      return adjustment.cents;
    case "tax":
      return Math.round((subtotalCents * adjustment.rate) / 100);
    default:
      return assertNever(adjustment);
  }
}

export function priceOrder(order: Order): PricedOrder {
  const lines: PricedLine[] = [];
  const rejected: string[] = [];
  let subtotalCents = 0;
  for (const item of order.items) {
    const line = priceLine(item);
    if (line === null) {
      rejected.push(item.sku);
      continue;
    }
    subtotalCents += line.netCents;
    lines.push(line);
  }
  let adjustmentCents = 0;
  for (const adjustment of order.adjustments) {
    adjustmentCents += adjustmentValue(adjustment, subtotalCents);
  }
  return {
    id: order.id,
    lines,
    rejected,
    adjustments: [...order.adjustments],
    subtotalCents,
    adjustmentCents,
    totalCents: Math.max(0, subtotalCents + adjustmentCents),
  };
}

function money(cents: number): string {
  const sign = cents < 0 ? "-" : "";
  const abs = Math.abs(cents);
  return `${sign}${Math.floor(abs / 100)}.${String(abs % 100).padStart(2, "0")}`;
}

function label(adjustment: Adjustment): string {
  switch (adjustment.kind) {
    case "credit":
      return "CREDIT";
    case "fee":
      return `FEE (${adjustment.reason})`;
    case "tax":
      return `TAX ${adjustment.rate}%`;
    default:
      return assertNever(adjustment);
  }
}

export function buildReceipt(priced: PricedOrder): string[] {
  const out: string[] = [`ORDER ${priced.id}`];
  for (const line of priced.lines) {
    out.push(`${line.name} x${line.qty} ${money(line.netCents)}`);
  }
  out.push(`SUBTOTAL ${money(priced.subtotalCents)}`);
  for (const adjustment of priced.adjustments) {
    out.push(
      `${label(adjustment)} ${money(adjustmentValue(adjustment, priced.subtotalCents))}`,
    );
  }
  out.push(`TOTAL ${money(priced.totalCents)}`);
  if (priced.rejected.length > 0) {
    out.push(`REJECTED ${priced.rejected.join(", ")}`);
  }
  return out;
}
