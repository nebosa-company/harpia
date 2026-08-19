/* Line pricing. Renamed from pricing.js; never typed. */
import { discountFor, findProduct } from "./catalog";

export function priceLine(item: any): any {
  var product = findProduct(item.sku);
  var gross = Math.round(product.priceCents * item.qty);
  return {
    sku: item.sku,
    name: product.name,
    category: product.category,
    qty: item.qty,
    grossCents: gross,
    netCents: applyDiscount(item.sku, gross),
  };
}

export function applyDiscount(sku: any, grossCents: any): any {
  var discount = discountFor(sku);
  if (discount !== undefined) {
    return grossCents - Math.round((grossCents * discount.percent) / 100);
  }
  return grossCents;
}
