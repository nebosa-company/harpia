// In-memory order storage.

export function createStore() {
  const orders = new Map(); // id -> order
  let nextId = 1; // monotonic: ids are never reused, deletions included

  return {
    insert(order) {
      const id = String(nextId);
      nextId += 1;
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
