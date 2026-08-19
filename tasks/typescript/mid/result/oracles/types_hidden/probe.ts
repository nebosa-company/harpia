import {
  all,
  andThen,
  err,
  fromThrowable,
  isErr,
  isOk,
  map,
  mapErr,
  orElse,
  partition,
  ok,
  unwrapOr,
} from "../src/result";
import type { Err, ErrOf, Ok, OkOf, Result } from "../src/result";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _Ok = Expect<Equals<ReturnType<typeof ok<string>>, Ok<string>>>;
type _Err = Expect<Equals<ReturnType<typeof err<"boom">>, Err<"boom">>>;
type _OkOf = Expect<Equals<OkOf<Result<number, string>>, number>>;
type _ErrOf = Expect<Equals<ErrOf<Result<number, string>>, string>>;
type _OkOfPlain = Expect<Equals<OkOf<{ a: 1 }>, never>>;

const literal = ok("x");
type _Literal = Expect<Equals<typeof literal, Ok<string>>>;

declare const r: Result<number, "io">;

const mapped = map(r, (n) => `${n}`);
type _Map = Expect<Equals<typeof mapped, Result<string, "io">>>;

const remapped = mapErr(r, (e) => ({ code: e }));
type _MapErr = Expect<Equals<typeof remapped, Result<number, { code: "io" }>>>;

declare function check(n: number): Result<number, "range">;
const chained = andThen(r, check);
type _AndThen = Expect<Equals<typeof chained, Result<number, "io" | "range">>>;

declare function recover(e: "io" | "range"): Result<string, "fatal">;
const recovered = orElse(chained, recover);
type _OrElse = Expect<Equals<typeof recovered, Result<number | string, "fatal">>>;

const fallback = unwrapOr(r, 0);
type _Unwrap = Expect<Equals<typeof fallback, number>>;

const gathered = all([ok(1), ok("a"), err("boom" as const)]);
if (!gathered.ok) {
  const reason: "boom" = gathered.error;
  void reason;
  // @ts-expect-error the only possible error here is "boom"
  const wrongReason: "other" = gathered.error;
  void wrongReason;
}

const gatheredOk = all([ok(1), ok("a")]);
if (gatheredOk.ok) {
  const tuple: [number, string] = gatheredOk.value;
  void tuple;
  // @ts-expect-error each position keeps its own type
  const swapped: [string, number] = gatheredOk.value;
  void swapped;
  // @ts-expect-error the tuple has exactly two entries
  const third: unknown = gatheredOk.value[2];
  void third;
}

const split = partition([ok(1), err("boom" as const)]);
type _Partition = Expect<Equals<typeof split, { values: number[]; errors: "boom"[] }>>;

const wrapped = fromThrowable(
  (raw: string, radix: number): number => Number.parseInt(raw, radix),
  (cause: unknown) => String(cause),
);
type _Wrapped = Expect<
  Equals<typeof wrapped, (raw: string, radix: number) => Result<number, string>>
>;
wrapped("ff", 16);

// @ts-expect-error the wrapper keeps the original parameter list
wrapped("ff");

if (isOk(r)) {
  const value: number = r.value;
  void value;
  // @ts-expect-error a success carries no error
  void r.error;
} else {
  const e: "io" = r.error;
  void e;
  // @ts-expect-error a failure carries no value
  void r.value;
}

if (isErr(r)) {
  const e: "io" = r.error;
  void e;
}

// @ts-expect-error the result must be narrowed before reading .value
const unguarded: number = r.value;
void unguarded;

// @ts-expect-error the chained error union is wider than "io"
const tooNarrow: Result<number, "io"> = chained;
void tooNarrow;

// @ts-expect-error the fallback must match the value type
unwrapOr(r, "zero");

export type {
  _Ok,
  _Err,
  _OkOf,
  _ErrOf,
  _OkOfPlain,
  _Literal,
  _Map,
  _MapErr,
  _AndThen,
  _OrElse,
  _Unwrap,
  _Partition,
  _Wrapped,
};
