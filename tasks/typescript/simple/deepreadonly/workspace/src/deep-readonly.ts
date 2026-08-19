/**
 * Deep immutability, on the type side and the runtime side.
 *
 * The two type aliases below are placeholders: they compile, but they
 * hand the type straight back without changing a single modifier.
 */
export type DeepReadonly<T> = T;

export type DeepMutable<T> = T;

export function deepFreeze<T>(value: T): DeepReadonly<T> {
  void value;
  throw new Error("deepFreeze is not implemented");
}

export function isDeeplyFrozen(value: unknown): boolean {
  void value;
  throw new Error("isDeeplyFrozen is not implemented");
}
