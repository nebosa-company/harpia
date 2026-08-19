// In-memory event emitter.

function checkEvent(event) {
  if (typeof event !== "string" && typeof event !== "symbol") {
    throw new TypeError("event must be a string or symbol");
  }
}

function checkHandler(handler) {
  if (typeof handler !== "function") {
    throw new TypeError("handler must be a function");
  }
}

export class Emitter {
  #events = new Map();

  #add(event, handler, once) {
    checkEvent(event);
    checkHandler(handler);
    let list = this.#events.get(event);
    if (!list) {
      list = [];
      this.#events.set(event, list);
    }
    const entry = { handler, once, removed: false };
    list.push(entry);
    return () => this.#drop(event, entry);
  }

  #drop(event, entry) {
    if (entry.removed) return false;
    entry.removed = true;
    const list = this.#events.get(event);
    if (!list) return false;
    const i = list.indexOf(entry);
    if (i !== -1) list.splice(i, 1);
    if (list.length === 0) this.#events.delete(event);
    return true;
  }

  on(event, handler) {
    return this.#add(event, handler, false);
  }

  once(event, handler) {
    return this.#add(event, handler, true);
  }

  off(event, handler) {
    checkEvent(event);
    checkHandler(handler);
    const list = this.#events.get(event);
    if (!list) return false;
    const entry = list.find((e) => e.handler === handler);
    if (!entry) return false;
    return this.#drop(event, entry);
  }

  emit(event, ...args) {
    checkEvent(event);
    const list = this.#events.get(event);
    if (!list || list.length === 0) return 0;
    const snapshot = [...list];
    let called = 0;
    let failed = false;
    let firstError;
    for (const entry of snapshot) {
      if (entry.removed) continue;
      if (entry.once) this.#drop(event, entry);
      called += 1;
      try {
        entry.handler.apply(this, args);
      } catch (err) {
        if (!failed) {
          failed = true;
          firstError = err;
        }
      }
    }
    if (failed) throw firstError;
    return called;
  }

  listenerCount(event) {
    checkEvent(event);
    return this.#events.get(event)?.length ?? 0;
  }

  events() {
    return [...this.#events.keys()];
  }
}
