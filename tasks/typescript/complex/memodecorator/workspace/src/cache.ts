/**
 * Memoisation helpers.
 *
 * The declarations below are placeholders. They compile, but every
 * wrapper has collapsed to "some function", so wrapping a function
 * throws away its parameter list and its return type.
 */
export interface MemoOptions<A extends unknown[]> {
  maxSize?: number;
  keyOf?: (...args: A) => string;
}

export interface Memoized<A extends unknown[], R> {
  (...args: A): R;
  readonly size: number;
  has(...args: A): boolean;
  clear(): void;
}

export interface CacheOptions {
  maxSize?: number;
  keyOf?: (args: readonly unknown[]) => string;
}

type LooseFn = (...args: never[]) => unknown;

export function memoize(fn: LooseFn, options?: CacheOptions): LooseFn {
  void fn;
  void options;
  throw new Error("memoize is not implemented");
}

export function cached(target: LooseFn, context: unknown): LooseFn {
  void target;
  void context;
  throw new Error("cached is not implemented");
}

export function cachedWith(
  options: CacheOptions,
): (target: LooseFn, context: unknown) => LooseFn {
  void options;
  throw new Error("cachedWith is not implemented");
}

export function methodCacheSize(instance: object, method: string): number {
  void instance;
  void method;
  throw new Error("methodCacheSize is not implemented");
}

export function clearMethodCache(instance: object, method: string): void {
  void instance;
  void method;
  throw new Error("clearMethodCache is not implemented");
}
