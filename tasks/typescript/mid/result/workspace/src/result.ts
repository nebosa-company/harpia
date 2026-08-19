/**
 * The error-handling vocabulary.
 *
 * The declarations below are placeholders. They compile, but every
 * combinator collapses its type parameters, so the error side of a
 * chain is lost the moment it is composed.
 */
export type Ok<T> = { readonly ok: true; readonly value: T };

export type Err<E> = { readonly ok: false; readonly error: E };

export type Result<T, E> = Ok<T> | Err<E>;

export type OkOf<R> = unknown;

export type ErrOf<R> = unknown;

function unimplemented(name: string): never {
  throw new Error(`${name} is not implemented`);
}

export function ok(value: unknown): Result<unknown, unknown> {
  void value;
  return unimplemented("ok");
}

export function err(error: unknown): Result<unknown, unknown> {
  void error;
  return unimplemented("err");
}

export function isOk(result: Result<unknown, unknown>): boolean {
  void result;
  return unimplemented("isOk");
}

export function isErr(result: Result<unknown, unknown>): boolean {
  void result;
  return unimplemented("isErr");
}

export function map(
  result: Result<unknown, unknown>,
  fn: (value: unknown) => unknown,
): Result<unknown, unknown> {
  void result;
  void fn;
  return unimplemented("map");
}

export function mapErr(
  result: Result<unknown, unknown>,
  fn: (error: unknown) => unknown,
): Result<unknown, unknown> {
  void result;
  void fn;
  return unimplemented("mapErr");
}

export function andThen(
  result: Result<unknown, unknown>,
  fn: (value: unknown) => Result<unknown, unknown>,
): Result<unknown, unknown> {
  void result;
  void fn;
  return unimplemented("andThen");
}

export function orElse(
  result: Result<unknown, unknown>,
  fn: (error: unknown) => Result<unknown, unknown>,
): Result<unknown, unknown> {
  void result;
  void fn;
  return unimplemented("orElse");
}

export function unwrapOr(result: Result<unknown, unknown>, fallback: unknown): unknown {
  void result;
  void fallback;
  return unimplemented("unwrapOr");
}

export function unwrapOrElse(
  result: Result<unknown, unknown>,
  fn: (error: unknown) => unknown,
): unknown {
  void result;
  void fn;
  return unimplemented("unwrapOrElse");
}

export function all(
  results: readonly Result<unknown, unknown>[],
): Result<unknown[], unknown> {
  void results;
  return unimplemented("all");
}

export function partition(results: readonly Result<unknown, unknown>[]): {
  values: unknown[];
  errors: unknown[];
} {
  void results;
  return unimplemented("partition");
}

export function fromThrowable(
  fn: (...args: unknown[]) => unknown,
  onError: (cause: unknown) => unknown,
): (...args: unknown[]) => Result<unknown, unknown> {
  void fn;
  void onError;
  return unimplemented("fromThrowable");
}
