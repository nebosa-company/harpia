/** Deep immutability, on the type side and the runtime side. */

type Primitive = string | number | boolean | bigint | symbol | null | undefined;

export type DeepReadonly<T> = T extends Primitive
  ? T
  : T extends (...args: never[]) => unknown
    ? T
    : T extends Date
      ? T
      : T extends ReadonlyMap<infer K, infer V>
        ? ReadonlyMap<DeepReadonly<K>, DeepReadonly<V>>
        : T extends ReadonlySet<infer U>
          ? ReadonlySet<DeepReadonly<U>>
          : { readonly [K in keyof T]: DeepReadonly<T[K]> };

export type DeepMutable<T> = T extends Primitive
  ? T
  : T extends (...args: never[]) => unknown
    ? T
    : T extends Date
      ? T
      : T extends ReadonlyMap<infer K, infer V>
        ? Map<DeepMutable<K>, DeepMutable<V>>
        : T extends ReadonlySet<infer U>
          ? Set<DeepMutable<U>>
          : { -readonly [K in keyof T]: DeepMutable<T[K]> };

const isObjectLike = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

export function deepFreeze<T>(value: T): DeepReadonly<T> {
  freeze(value);
  return value as DeepReadonly<T>;
}

function freeze(value: unknown): void {
  if (!isObjectLike(value)) return;
  if (Object.isFrozen(value)) return;
  Object.freeze(value);
  for (const key of Object.keys(value)) {
    freeze(value[key]);
  }
}

export function isDeeplyFrozen(value: unknown): boolean {
  return checkFrozen(value, new Set<object>());
}

function checkFrozen(value: unknown, seen: Set<object>): boolean {
  if (typeof value === "function") return true;
  if (!isObjectLike(value)) return true;
  if (seen.has(value)) return true;
  seen.add(value);
  if (!Object.isFrozen(value)) return false;
  for (const key of Object.keys(value)) {
    if (!checkFrozen(value[key], seen)) return false;
  }
  return true;
}
