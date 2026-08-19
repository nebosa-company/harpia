// In-memory append-only event store with live projections.
// The full contract (seq/version numbering, expectedVersion, projection
// replay, error codes) is in the project brief.

export class EventStore {
  append(streamId, type, data, options = {}) {
    throw new Error("not implemented");
  }

  readStream(streamId) {
    throw new Error("not implemented");
  }

  readAll(options = {}) {
    throw new Error("not implemented");
  }

  registerProjection(name, handlers) {
    throw new Error("not implemented");
  }

  getProjection(name) {
    throw new Error("not implemented");
  }
}
