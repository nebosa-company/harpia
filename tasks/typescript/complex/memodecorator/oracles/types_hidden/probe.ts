import { cached, cachedWith, clearMethodCache, memoize, methodCacheSize } from "../src/cache";
import type { Memoized } from "../src/cache";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

const join = memoize((count: number, label: string): string => `${label}:${count}`);

type _Memoized = Expect<Equals<typeof join, Memoized<[number, string], string>>>;
type _Size = Expect<Equals<typeof join.size, number>>;
type _Has = Expect<Equals<ReturnType<typeof join.has>, boolean>>;
type _Clear = Expect<Equals<ReturnType<typeof join.clear>, void>>;
type _CacheSize = Expect<Equals<ReturnType<typeof methodCacheSize>, number>>;
type _ClearCache = Expect<Equals<ReturnType<typeof clearMethodCache>, void>>;

const text: string = join(1, "a");
void text;
join.clear();
join.has(1, "a");

// @ts-expect-error the wrapper keeps the original parameter types
join("1", "a");

// @ts-expect-error the wrapper keeps the original arity
join(1);

// @ts-expect-error the wrapper keeps the original return type
const wrongReturn: number = join(1, "a");
void wrongReturn;

// @ts-expect-error has takes the wrapped function's parameters
join.has("1", "a");

// @ts-expect-error size is read-only
join.size = 3;

const withOptions = memoize(
  (count: number, label: string): string => `${label}:${count}`,
  { maxSize: 4, keyOf: (count, label) => `${label}/${count}` },
);
type _WithOptions = Expect<
  Equals<typeof withOptions, Memoized<[number, string], string>>
>;

memoize((n: number): number => n, {
  // @ts-expect-error keyOf receives the wrapped function's parameters
  keyOf: (n: string) => n,
});

memoize((n: number): number => n, {
  // @ts-expect-error keyOf returns the cache key as a string
  keyOf: (n) => n,
});

class Calc {
  offset = 1;

  @cached
  square(n: number): number {
    return n * n + this.offset;
  }

  @cachedWith({ maxSize: 2 })
  label(n: number, prefix: string): string {
    return `${prefix}${n}`;
  }
}

const calc = new Calc();
type _Square = Expect<Equals<typeof calc.square, (n: number) => number>>;
type _Label = Expect<Equals<typeof calc.label, (n: number, prefix: string) => string>>;

const squared: number = calc.square(2);
const labelled: string = calc.label(2, "n");
void squared;
void labelled;

// @ts-expect-error the decorated method keeps its parameter type
calc.square("2");

// @ts-expect-error the decorated method keeps its return type
const wrongMethodReturn: string = calc.square(2);
void wrongMethodReturn;

// @ts-expect-error the decorated method keeps its arity
calc.label(2);

methodCacheSize(calc, "square");
clearMethodCache(calc, "square");

// @ts-expect-error the helpers take an object instance
methodCacheSize("calc", "square");

export type {
  _Memoized,
  _Size,
  _Has,
  _Clear,
  _CacheSize,
  _ClearCache,
  _WithOptions,
  _Square,
  _Label,
};
