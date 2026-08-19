/**
 * A small synchronous event emitter, keyed on an event map.
 */
export type EventMap = Record<string, unknown>;

export interface Emitter<M extends EventMap> {
  on<K extends keyof M>(event: K, listener: (payload: M[K]) => void): () => void;
  once<K extends keyof M>(event: K, listener: (payload: M[K]) => void): () => void;
  off<K extends keyof M>(event: K, listener: (payload: M[K]) => void): void;
  emit<K extends keyof M>(event: K, payload: M[K]): number;
  listenerCount<K extends keyof M>(event: K): number;
}

type AnyListener = (payload: never) => void;

interface Entry {
  /** what actually runs (the `once` wrapper, or the listener itself) */
  run: (payload: never) => void;
  /** what the caller passed, so `off` can find it again */
  orig: AnyListener;
}

export function createEmitter<M extends EventMap>(): Emitter<M> {
  const registry = new Map<keyof M, Entry[]>();

  const bucket = (event: keyof M): Entry[] => {
    let arr = registry.get(event);
    if (arr === undefined) {
      arr = [];
      registry.set(event, arr);
    }
    return arr;
  };

  const drop = (event: keyof M, entry: Entry): void => {
    const arr = registry.get(event);
    if (arr === undefined) return;
    const i = arr.indexOf(entry);
    if (i >= 0) arr.splice(i, 1);
  };

  return {
    on<K extends keyof M>(event: K, listener: (payload: M[K]) => void): () => void {
      const entry: Entry = {
        run: listener as (payload: never) => void,
        orig: listener as AnyListener,
      };
      bucket(event).push(entry);
      return () => drop(event, entry);
    },

    once<K extends keyof M>(event: K, listener: (payload: M[K]) => void): () => void {
      const entry: Entry = {
        run: (payload: never) => {
          drop(event, entry);
          (listener as (payload: never) => void)(payload);
        },
        orig: listener as AnyListener,
      };
      bucket(event).push(entry);
      return () => drop(event, entry);
    },

    off<K extends keyof M>(event: K, listener: (payload: M[K]) => void): void {
      const arr = registry.get(event);
      if (arr === undefined) return;
      const target = listener as AnyListener;
      const i = arr.findIndex((e) => e.orig === target);
      if (i >= 0) arr.splice(i, 1);
    },

    emit<K extends keyof M>(event: K, payload: M[K]): number {
      const arr = registry.get(event);
      if (arr === undefined || arr.length === 0) return 0;
      const snapshot = arr.slice();
      let called = 0;
      for (const entry of snapshot) {
        const live = registry.get(event);
        if (live === undefined || live.indexOf(entry) < 0) continue;
        called += 1;
        (entry.run as (payload: M[K]) => void)(payload);
      }
      return called;
    },

    listenerCount<K extends keyof M>(event: K): number {
      return registry.get(event)?.length ?? 0;
    },
  };
}
