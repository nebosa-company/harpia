/** A transition-table state machine that carries its state in its type. */
export type TransitionTable = Record<string, Record<string, string>>;

export type StateOf<T extends TransitionTable> = keyof T & string;

export type EventOf<T extends TransitionTable, S extends StateOf<T>> = keyof T[S] &
  string;

export type NextState<
  T extends TransitionTable,
  S extends StateOf<T>,
  E extends EventOf<T, S>,
> = T[S][E] & StateOf<T>;

export interface Machine<T extends TransitionTable, S extends StateOf<T>> {
  readonly state: S;
  readonly history: readonly StateOf<T>[];
  can(event: string): boolean;
  send<E extends EventOf<T, S>>(event: E): Machine<T, NextState<T, S, E>>;
}

function build<T extends TransitionTable, S extends StateOf<T>>(
  table: T,
  state: S,
  history: readonly StateOf<T>[],
): Machine<T, S> {
  const rows = table as Record<string, Record<string, string> | undefined>;
  return {
    state,
    history,
    can(event: string): boolean {
      const row = rows[state];
      return row !== undefined && Object.hasOwn(row, event);
    },
    send<E extends EventOf<T, S>>(event: E): Machine<T, NextState<T, S, E>> {
      const row = rows[state];
      const next = row === undefined ? undefined : row[event as string];
      if (next === undefined) {
        throw new RangeError(`invalid transition: ${String(state)} + ${String(event)}`);
      }
      const target = next as NextState<T, S, E>;
      return build<T, NextState<T, S, E>>(table, target, [
        ...history,
        target as StateOf<T>,
      ]);
    },
  };
}

export function createMachine<const T extends TransitionTable, S extends StateOf<T>>(
  table: T,
  initial: S,
): Machine<T, S> {
  return build<T, S>(table, initial, [initial]);
}

export function isValidTransition<T extends TransitionTable>(
  table: T,
  from: string,
  event: string,
): boolean {
  const rows = table as Record<string, Record<string, string> | undefined>;
  const row = rows[from];
  return row !== undefined && Object.hasOwn(row, event);
}

export function reachableFrom<T extends TransitionTable>(
  table: T,
  from: StateOf<T>,
): StateOf<T>[] {
  const rows = table as Record<string, Record<string, string> | undefined>;
  const seen = new Set<string>();
  const queue: string[] = Object.values(rows[from] ?? {});
  while (queue.length > 0) {
    const state = queue.shift() as string;
    if (seen.has(state)) continue;
    seen.add(state);
    queue.push(...Object.values(rows[state] ?? {}));
  }
  return [...seen].sort() as StateOf<T>[];
}
