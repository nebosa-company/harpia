/* The product catalogue. Renamed from catalog.js; never typed.
 * Convention here has always been: no discount means null. */

export const PRODUCTS: any = [
  { sku: "BK-1", name: "Notebook", priceCents: 450, category: "stationery" },
  { sku: "PN-2", name: "Pen", priceCents: 150, category: "stationery" },
  { sku: "MG-3", name: "Mug", priceCents: 900, category: "kitchen" },
  { sku: "TE-4", name: "Tea", priceCents: 600, category: "kitchen" },
];

export const DISCOUNTS: any = [
  { sku: "MG-3", percent: 20 },
  { sku: "TE-4", percent: 10 },
];

export function findProduct(sku: any): any {
  for (var i = 0; i < PRODUCTS.length; i++) {
    if (PRODUCTS[i].sku === sku) {
      return PRODUCTS[i];
    }
  }
  return undefined;
}

export function discountFor(sku: any): any {
  for (var i = 0; i < DISCOUNTS.length; i++) {
    if (DISCOUNTS[i].sku === sku) {
      return DISCOUNTS[i];
    }
  }
  return null;
}
