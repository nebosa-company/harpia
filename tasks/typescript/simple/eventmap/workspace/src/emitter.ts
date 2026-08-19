/**
 * A small synchronous event emitter.
 *
 * `EventMap` maps an event name to the payload that event carries. The
 * declarations below are placeholders: they compile, but they lose the
 * per-event payload type and nothing is wired up yet.
 */
export type EventMap = Record<string, unknown>;

export interface Emitter<M extends EventMap> {
  on(event: keyof M, listener: (payload: unknown) => void): () => void;
  once(event: keyof M, listener: (payload: unknown) => void): () => void;
  off(event: keyof M, listener: (payload: unknown) => void): void;
  emit(event: keyof M, payload: unknown): number;
  listenerCount(event: keyof M): number;
}

export function createEmitter<M extends EventMap>(): Emitter<M> {
  throw new Error("createEmitter is not implemented");
}
