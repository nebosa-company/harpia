export class EventStore {
  #events = [];
  #streams = new Map(); // streamId -> events
  #projections = new Map(); // name -> { apply, state }

  append(streamId, type, data, options = {}) {
    const stream = this.#streams.get(streamId) ?? [];
    const currentVersion = stream.length;
    if (
      options.expectedVersion !== undefined &&
      options.expectedVersion !== currentVersion
    ) {
      const err = new Error(
        `concurrency conflict on ${streamId}: expected ${options.expectedVersion}, at ${currentVersion}`,
      );
      err.code = "CONCURRENCY";
      throw err;
    }
    const record = {
      seq: this.#events.length + 1,
      streamId,
      version: currentVersion + 1,
      type,
      data,
    };
    this.#events.push(record);
    if (!this.#streams.has(streamId)) this.#streams.set(streamId, stream);
    stream.push(record);
    for (const projection of this.#projections.values()) {
      projection.state = projection.apply(projection.state, record);
    }
    return record;
  }

  readStream(streamId) {
    return [...(this.#streams.get(streamId) ?? [])];
  }

  readAll(options = {}) {
    const { fromSeq = 1 } = options;
    return this.#events.filter((e) => e.seq >= fromSeq);
  }

  registerProjection(name, { init, apply }) {
    if (this.#projections.has(name)) {
      const err = new Error(`projection already registered: ${name}`);
      err.code = "DUPLICATE_PROJECTION";
      throw err;
    }
    let state = init();
    for (const event of this.#events) {
      state = apply(state, event);
    }
    this.#projections.set(name, { apply, state });
  }

  getProjection(name) {
    const projection = this.#projections.get(name);
    if (!projection) {
      const err = new Error(`unknown projection: ${name}`);
      err.code = "UNKNOWN_PROJECTION";
      throw err;
    }
    return projection.state;
  }
}
