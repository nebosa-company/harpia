/** The product catalogue. No discount is signalled with `null`. */
export interface Product {
  sku: string;
  name: string;
  priceCents: number;
  category: string;
}

export interface Discount {
  sku: string;
  percent: number;
}

export const PRODUCTS: readonly Product[] = [
  { sku: "BK-1", name: "Notebook", priceCents: 450, category: "stationery" },
  { sku: "PN-2", name: "Pen", priceCents: 150, category: "stationery" },
  { sku: "MG-3", name: "Mug", priceCents: 900, category: "kitchen" },
  { sku: "TE-4", name: "Tea", priceCents: 600, category: "kitchen" },
];

export const DISCOUNTS: readonly Discount[] = [
  { sku: "MG-3", percent: 20 },
  { sku: "TE-4", percent: 10 },
];

export function findProduct(sku: string): Product | undefined {
  return PRODUCTS.find((product) => product.sku === sku);
}

export function discountFor(sku: string): Discount | null {
  return DISCOUNTS.find((discount) => discount.sku === sku) ?? null;
}
