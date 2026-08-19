// Product and coupon data, published by the merchandising service.
// Fixed input: prices are integer cents, coupon values are whole percent
// for "percent" coupons and integer cents for "amount" coupons.

export const products = {
  "SKU-WIDGET": { name: "Widget", price: 1299 },
  "SKU-GADGET": { name: "Gadget", price: 450 },
  "SKU-TRINKET": { name: "Trinket", price: 89 },
  "SKU-ANVIL": { name: "Anvil", price: 7500 },
};

export const coupons = {
  SAVE10: { kind: "percent", value: 10, minSubtotal: 0 },
  SAVE25: { kind: "percent", value: 25, minSubtotal: 5000 },
  FIVEOFF: { kind: "amount", value: 500, minSubtotal: 1000 },
  BIGDEAL: { kind: "amount", value: 100000, minSubtotal: 0 },
};

export const catalog = { products, coupons };
