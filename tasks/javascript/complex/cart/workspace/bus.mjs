// The shared event bus. Fixed infrastructure: other services subscribe to
// these events, so the API here does not change.

export function createBus() {
  const handlers = new Map();

  return {
    on(event, handler) {
      if (typeof event !== "string") throw new TypeError("event must be a string");
      if (typeof handler !== "function") throw new TypeError("handler must be a function");
      let list = handlers.get(event);
      if (!list) {
        list = [];
        handlers.set(event, list);
      }
      list.push(handler);
      return () => {
        const i = list.indexOf(handler);
        if (i === -1) return false;
        list.splice(i, 1);
        return true;
      };
    },

    off(event, handler) {
      const list = handlers.get(event);
      if (!list) return false;
      const i = list.indexOf(handler);
      if (i === -1) return false;
      list.splice(i, 1);
      return true;
    },

    emit(event, payload) {
      const list = handlers.get(event);
      if (!list || list.length === 0) return 0;
      const snapshot = [...list];
      for (const handler of snapshot) handler(payload);
      return snapshot.length;
    },

    listenerCount(event) {
      return handlers.get(event)?.length ?? 0;
    },
  };
}
