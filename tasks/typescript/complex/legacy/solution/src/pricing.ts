/** Line pricing. */
import { discountFor, findProduct } from "./catalog";

export interface OrderLine {
  sku: string;
  qty: number;
}

export interface PricedLine {
  sku: string;
  name: string;
  category: string;
  qty: number;
  grossCents: number;
  netCents: number;
}

export function priceLine(item: OrderLine): PricedLine | null {
  const product = findProduct(item.sku);
  if (product === undefined) return null;
  const grossCents = Math.round(product.priceCents * item.qty);
  return {
    sku: item.sku,
    name: product.name,
    category: product.category,
    qty: item.qty,
    grossCents,
    netCents: applyDiscount(item.sku, grossCents),
  };
}

export function applyDiscount(sku: string, grossCents: number): number {
  const discount = discountFor(sku);
  if (discount === null) return grossCents;
  return grossCents - Math.round((grossCents * discount.percent) / 100);
}
