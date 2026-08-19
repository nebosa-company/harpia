// In-memory event emitter. See the project brief for the exact semantics.

export class Emitter {
  on(event, handler) {
    throw new Error("not implemented");
  }

  once(event, handler) {
    throw new Error("not implemented");
  }

  off(event, handler) {
    throw new Error("not implemented");
  }

  emit(event, ...args) {
    throw new Error("not implemented");
  }

  listenerCount(event) {
    throw new Error("not implemented");
  }

  events() {
    throw new Error("not implemented");
  }
}
