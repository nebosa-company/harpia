/**
 * A transition-table state machine.
 *
 * The declarations below are placeholders. They compile, but every
 * state and event has widened to `string`, so the compiler cannot tell
 * a legal transition from an illegal one.
 */
export type TransitionTable = Record<string, Record<string, string>>;

export type StateOf<T extends TransitionTable> = string;

export type EventOf<T extends TransitionTable, S extends string> = string;

export type NextState<
  T extends TransitionTable,
  S extends string,
  E extends string,
> = string;

export interface Machine<T extends TransitionTable, S extends StateOf<T>> {
  readonly state: string;
  readonly history: readonly string[];
  can(event: string): boolean;
  send(event: string): Machine<T, S>;
}

export function createMachine<T extends TransitionTable, S extends StateOf<T>>(
  table: T,
  initial: S,
): Machine<T, S> {
  void table;
  void initial;
  throw new Error("createMachine is not implemented");
}

export function isValidTransition<T extends TransitionTable>(
  table: T,
  from: string,
  event: string,
): boolean {
  void table;
  void from;
  void event;
  throw new Error("isValidTransition is not implemented");
}

export function reachableFrom<T extends TransitionTable>(
  table: T,
  from: StateOf<T>,
): StateOf<T>[] {
  void table;
  void from;
  throw new Error("reachableFrom is not implemented");
}
