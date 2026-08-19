// In-memory order storage.

export function createStore() {
  const orders = new Map(); // id -> order

  return {
    insert(order) {
      const id = String(orders.size + 1);
      const stored = { id, ...order };
      orders.set(id, stored);
      return stored;
    },
    get(id) {
      return orders.get(id) ?? null;
    },
    remove(id) {
      return orders.delete(id);
    },
    list() {
      return [...orders.values()];
    },
  };
}
