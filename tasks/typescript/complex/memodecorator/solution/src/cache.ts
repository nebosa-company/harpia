/** Memoisation helpers that keep the signatures they wrap. */
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

function checkMaxSize(maxSize: number | undefined): number | null {
  if (maxSize === undefined) return null;
  if (!Number.isInteger(maxSize) || maxSize <= 0) {
    throw new RangeError("maxSize must be a positive integer");
  }
  return maxSize;
}

/** Least-recently-used store: Map preserves insertion order, so the
 *  first key is the least recently used. */
class Lru {
  readonly entries = new Map<string, unknown>();

  constructor(private readonly maxSize: number | null) {}

  read(key: string): { hit: boolean; value: unknown } {
    if (!this.entries.has(key)) return { hit: false, value: undefined };
    const value = this.entries.get(key);
    this.entries.delete(key);
    this.entries.set(key, value);
    return { hit: true, value };
  }

  write(key: string, value: unknown): void {
    this.entries.delete(key);
    this.entries.set(key, value);
    if (this.maxSize !== null) {
      while (this.entries.size > this.maxSize) {
        const oldest = this.entries.keys().next();
        if (oldest.done === true) break;
        this.entries.delete(oldest.value);
      }
    }
  }
}

export function memoize<A extends unknown[], R>(fn: (...args: A) => R): Memoized<A, R>;
export function memoize<A extends unknown[], R>(
  fn: (...args: A) => R,
  options: MemoOptions<A>,
): Memoized<A, R>;
export function memoize<A extends unknown[], R>(
  fn: (...args: A) => R,
  options: MemoOptions<A> = {},
): Memoized<A, R> {
  const store = new Lru(checkMaxSize(options.maxSize));
  const keyOf = options.keyOf;
  const key = (args: A): string =>
    keyOf === undefined ? JSON.stringify(args) : keyOf(...args);

  function wrapper(this: unknown, ...args: A): R {
    const k = key(args);
    const found = store.read(k);
    if (found.hit) return found.value as R;
    const value = fn.apply(this, args);
    store.write(k, value);
    return value;
  }

  const memoized = wrapper as unknown as {
    (...args: A): R;
    has(...args: A): boolean;
    clear(): void;
  };
  memoized.has = (...args: A): boolean => store.entries.has(key(args));
  memoized.clear = (): void => {
    store.entries.clear();
  };
  Object.defineProperty(memoized, "size", {
    get: (): number => store.entries.size,
    enumerable: false,
    configurable: true,
  });
  return memoized as Memoized<A, R>;
}

const methodCaches = new WeakMap<object, Map<string, Lru>>();

function storeFor(instance: object, method: string, maxSize: number | null): Lru {
  let byMethod = methodCaches.get(instance);
  if (byMethod === undefined) {
    byMethod = new Map<string, Lru>();
    methodCaches.set(instance, byMethod);
  }
  let store = byMethod.get(method);
  if (store === undefined) {
    store = new Lru(maxSize);
    byMethod.set(method, store);
  }
  return store;
}

function decorate<This, A extends unknown[], R>(
  target: (this: This, ...args: A) => R,
  method: string,
  options: CacheOptions,
): (this: This, ...args: A) => R {
  const maxSize = checkMaxSize(options.maxSize);
  const keyOf = options.keyOf;
  return function replacement(this: This, ...args: A): R {
    const store = storeFor(this as object, method, maxSize);
    const key = keyOf === undefined ? JSON.stringify(args) : keyOf(args);
    const found = store.read(key);
    if (found.hit) return found.value as R;
    const value = target.apply(this, args);
    store.write(key, value);
    return value;
  };
}

export function cached<This, A extends unknown[], R>(
  target: (this: This, ...args: A) => R,
  context: ClassMethodDecoratorContext<This, (this: This, ...args: A) => R>,
): (this: This, ...args: A) => R {
  return decorate(target, String(context.name), {});
}

export function cachedWith(
  options: CacheOptions,
): <This, A extends unknown[], R>(
  target: (this: This, ...args: A) => R,
  context: ClassMethodDecoratorContext<This, (this: This, ...args: A) => R>,
) => (this: This, ...args: A) => R {
  checkMaxSize(options.maxSize);
  return <This, A extends unknown[], R>(
    target: (this: This, ...args: A) => R,
    context: ClassMethodDecoratorContext<This, (this: This, ...args: A) => R>,
  ): ((this: This, ...args: A) => R) => decorate(target, String(context.name), options);
}

export function methodCacheSize(instance: object, method: string): number {
  return methodCaches.get(instance)?.get(method)?.entries.size ?? 0;
}

export function clearMethodCache(instance: object, method: string): void {
  methodCaches.get(instance)?.get(method)?.entries.clear();
}
