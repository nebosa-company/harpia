// The shopping cart. Lines live in memory; everything else in the app finds
// out about changes through the bus.

import { lineTotal, sumLines, discountFor } from "./pricing.mjs";

function snapshot(line) {
  return {
    sku: line.sku,
    name: line.name,
    qty: line.qty,
    unitPrice: line.unitPrice,
    lineTotal: lineTotal(line),
  };
}

export function createCart({ bus, catalog }) {
  if (!bus || !catalog) throw new TypeError("createCart needs a bus and a catalog");

  const lines = [];
  const subscriptions = new Map();
  let couponCode = null;

  function find(sku) {
    return lines.find((line) => line.sku === sku);
  }

  function watch(line) {
    if (subscriptions.has(line.sku)) return;
    const unsubscribe = bus.on("price:updated", (event) => {
      if (!event || event.sku !== line.sku) return;
      if (!lines.includes(line)) return;
      line.unitPrice = event.price;
      bus.emit("change", { reason: "price", sku: line.sku });
    });
    subscriptions.set(line.sku, unsubscribe);
  }

  function unwatch(sku) {
    const unsubscribe = subscriptions.get(sku);
    if (!unsubscribe) return;
    unsubscribe();
    subscriptions.delete(sku);
  }

  const cart = {
    addItem(sku, qty = 1) {
      const product = catalog.products[sku];
      if (!product) {
        const err = new Error(`unknown sku ${sku}`);
        err.code = "UNKNOWN_SKU";
        throw err;
      }
      if (!Number.isInteger(qty) || qty < 1) {
        throw new TypeError("qty must be a positive integer");
      }

      const existing = find(sku);
      if (existing) {
        existing.qty += qty;
      } else {
        const line = { sku, name: product.name, unitPrice: product.price, qty };
        lines.push(line);
        watch(line);
      }
      bus.emit("change", { reason: "add", sku });
      return snapshot(find(sku));
    },

    removeItem(sku) {
      const index = lines.findIndex((line) => line.sku === sku);
      if (index === -1) return false;
      lines.splice(index, 1);
      unwatch(sku);
      bus.emit("change", { reason: "remove", sku });
      return true;
    },

    setQuantity(sku, qty) {
      const line = find(sku);
      if (!line) {
        const err = new Error(`no line for ${sku}`);
        err.code = "NO_SUCH_LINE";
        throw err;
      }
      if (!Number.isInteger(qty) || qty < 0) {
        throw new TypeError("qty must be a non-negative integer");
      }
      if (qty === 0) {
        cart.removeItem(sku);
        return null;
      }
      line.qty = qty;
      bus.emit("change", { reason: "quantity", sku });
      return snapshot(line);
    },

    clear() {
      lines.length = 0;
      for (const sku of [...subscriptions.keys()]) unwatch(sku);
      bus.emit("change", { reason: "clear", sku: null });
    },

    lines() {
      return lines.map((line) => snapshot(line));
    },

    applyCoupon(code) {
      const coupon = catalog.coupons[code];
      if (!coupon) {
        const err = new Error(`unknown coupon ${code}`);
        err.code = "UNKNOWN_COUPON";
        throw err;
      }
      const subtotal = cart.subtotal;
      if (subtotal < coupon.minSubtotal) {
        const err = new Error(`${code} needs a subtotal of at least ${coupon.minSubtotal}`);
        err.code = "COUPON_NOT_ELIGIBLE";
        throw err;
      }
      couponCode = code;
      bus.emit("coupon", { code, discount: cart.discount });
      bus.emit("change", { reason: "coupon", sku: null });
      return cart.total;
    },

    removeCoupon() {
      if (couponCode === null) return false;
      couponCode = null;
      bus.emit("coupon", { code: null, discount: 0 });
      bus.emit("change", { reason: "coupon", sku: null });
      return true;
    },

    get coupon() {
      return couponCode;
    },

    get itemCount() {
      return lines.reduce((count, line) => count + line.qty, 0);
    },

    get subtotal() {
      return sumLines(lines);
    },

    get discount() {
      return couponCode === null ? 0 : discountFor(catalog.coupons[couponCode], cart.subtotal);
    },

    get total() {
      return Math.max(0, cart.subtotal - cart.discount);
    },
  };

  return cart;
}
