// The shopping cart. Lines live in memory; everything else in the app finds
// out about changes through the bus.

import { lineTotal, sumLines } from "./pricing.mjs";

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
  let subtotalCache = 0;

  function recalculate() {
    subtotalCache = sumLines(lines);
  }

  function find(sku) {
    return lines.find((line) => line.sku === sku);
  }

  function watch(line) {
    bus.on("price:updated", (event) => {
      if (!event || event.sku !== line.sku) return;
      line.unitPrice = event.price;
      recalculate();
      bus.emit("change", { reason: "price", sku: line.sku });
    });
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
        cart.setQuantity(sku, existing.qty + qty);
        watch(existing);
      } else {
        const line = { sku, name: product.name, unitPrice: product.price, qty };
        lines.push(line);
        watch(line);
        recalculate();
      }
      bus.emit("change", { reason: "add", sku });
      return snapshot(find(sku));
    },

    removeItem(sku) {
      const index = lines.findIndex((line) => line.sku === sku);
      if (index === -1) return false;
      lines.splice(index, 1);
      recalculate();
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
      recalculate();
      bus.emit("change", { reason: "clear", sku: null });
    },

    lines() {
      return lines.map((line) => snapshot(line));
    },

    get itemCount() {
      return lines.reduce((count, line) => count + line.qty, 0);
    },

    get subtotal() {
      return subtotalCache;
    },

    get discount() {
      return 0;
    },

    get total() {
      return subtotalCache;
    },
  };

  return cart;
}
