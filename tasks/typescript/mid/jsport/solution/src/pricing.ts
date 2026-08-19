/** Order pricing, ported to strict TypeScript. */
export type Currency = "EUR" | "GBP" | "USD";

export interface LineItem {
  sku: string;
  qty: number;
  unitCents: number;
  category: string;
}

export interface Discount {
  code: string;
  kind: "percent" | "fixed";
  amount: number;
}

export interface PricedLine {
  sku: string;
  category: string;
  grossCents: number;
}

export interface PricedOrder {
  lines: PricedLine[];
  subtotalCents: number;
  discountCents: number;
  totalCents: number;
  currency: Currency;
}

export const DISCOUNTS: readonly Discount[] = [
  { code: "SAVE10", kind: "percent", amount: 10 },
  { code: "SAVE5", kind: "fixed", amount: 500 },
  { code: "HALF", kind: "percent", amount: 50 },
];

const SYMBOLS: Record<Currency, string> = { EUR: "€", GBP: "£", USD: "$" };

export function lineTotal(item: LineItem): number {
  if (!(item.qty > 0)) return 0;
  return Math.round(item.qty * item.unitCents);
}

export function findDiscount(code: string): Discount | undefined {
  return DISCOUNTS.find((discount) => discount.code === code);
}

export function applyDiscount(subtotalCents: number, code: string | null): number {
  if (code === null) return subtotalCents;
  const discount = findDiscount(code);
  if (discount === undefined) return subtotalCents;
  let off =
    discount.kind === "percent"
      ? Math.round((subtotalCents * discount.amount) / 100)
      : discount.amount;
  if (off > subtotalCents) off = subtotalCents;
  if (off < 0) off = 0;
  return subtotalCents - off;
}

export function priceOrder(
  items: readonly LineItem[],
  code: string | null,
  currency: Currency,
): PricedOrder {
  const lines: PricedLine[] = [];
  let subtotalCents = 0;
  for (const item of items) {
    const grossCents = lineTotal(item);
    subtotalCents += grossCents;
    lines.push({ sku: item.sku, category: item.category, grossCents });
  }
  const totalCents = applyDiscount(subtotalCents, code);
  return {
    lines,
    subtotalCents,
    discountCents: subtotalCents - totalCents,
    totalCents,
    currency,
  };
}

export function formatMoney(cents: number, currency: Currency): string {
  if (!Number.isInteger(cents)) {
    throw new RangeError("cents must be a whole number");
  }
  const sign = cents < 0 ? "-" : "";
  const abs = Math.abs(cents);
  const units = Math.floor(abs / 100);
  const rest = String(abs % 100).padStart(2, "0");
  return `${sign}${SYMBOLS[currency]}${units}.${rest}`;
}

export function summarizeByCategory(
  order: PricedOrder,
): Array<{ category: string; grossCents: number; share: number }> {
  const totals = new Map<string, number>();
  for (const line of order.lines) {
    totals.set(line.category, (totals.get(line.category) ?? 0) + line.grossCents);
  }
  const subtotal = order.subtotalCents;
  return [...totals.entries()]
    .map(([category, grossCents]) => ({
      category,
      grossCents,
      share: subtotal === 0 ? 0 : Math.round((grossCents / subtotal) * 10000) / 10000,
    }))
    .sort((a, b) =>
      b.grossCents !== a.grossCents
        ? b.grossCents - a.grossCents
        : a.category < b.category
          ? -1
          : a.category > b.category
            ? 1
            : 0,
    );
}
