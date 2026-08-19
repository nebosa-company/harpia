/** The error-handling vocabulary, with the error union carried along. */
export type Ok<T> = { readonly ok: true; readonly value: T };

export type Err<E> = { readonly ok: false; readonly error: E };

export type Result<T, E> = Ok<T> | Err<E>;

export type OkOf<R> = R extends Ok<infer T> ? T : never;

export type ErrOf<R> = R extends Err<infer E> ? E : never;

export function ok<T>(value: T): Ok<T> {
  return { ok: true, value };
}

export function err<E>(error: E): Err<E> {
  return { ok: false, error };
}

export function isOk<T, E>(result: Result<T, E>): result is Ok<T> {
  return result.ok;
}

export function isErr<T, E>(result: Result<T, E>): result is Err<E> {
  return !result.ok;
}

export function map<T, E, U>(result: Result<T, E>, fn: (value: T) => U): Result<U, E> {
  return result.ok ? ok(fn(result.value)) : err(result.error);
}

export function mapErr<T, E, F>(
  result: Result<T, E>,
  fn: (error: E) => F,
): Result<T, F> {
  return result.ok ? ok(result.value) : err(fn(result.error));
}

export function andThen<T, E, U, F>(
  result: Result<T, E>,
  fn: (value: T) => Result<U, F>,
): Result<U, E | F> {
  return result.ok ? fn(result.value) : err<E | F>(result.error);
}

export function orElse<T, E, U, F>(
  result: Result<T, E>,
  fn: (error: E) => Result<U, F>,
): Result<T | U, F> {
  return result.ok ? ok<T | U>(result.value) : fn(result.error);
}

export function unwrapOr<T, E>(result: Result<T, E>, fallback: T): T {
  return result.ok ? result.value : fallback;
}

export function unwrapOrElse<T, E>(result: Result<T, E>, fn: (error: E) => T): T {
  return result.ok ? result.value : fn(result.error);
}

type AnyResult = Result<unknown, unknown>;

export function all<const R extends readonly AnyResult[]>(
  results: R,
): Result<{ -readonly [K in keyof R]: OkOf<R[K]> }, ErrOf<R[number]>> {
  const values: unknown[] = [];
  for (const result of results) {
    if (!result.ok) {
      return result as Err<ErrOf<R[number]>>;
    }
    values.push(result.value);
  }
  return ok(values as { -readonly [K in keyof R]: OkOf<R[K]> });
}

export function partition<T, E>(
  results: readonly Result<T, E>[],
): { values: T[]; errors: E[] } {
  const values: T[] = [];
  const errors: E[] = [];
  for (const result of results) {
    if (result.ok) {
      values.push(result.value);
    } else {
      errors.push(result.error);
    }
  }
  return { values, errors };
}

export function fromThrowable<A extends unknown[], T, E>(
  fn: (...args: A) => T,
  onError: (cause: unknown) => E,
): (...args: A) => Result<T, E> {
  return (...args: A): Result<T, E> => {
    try {
      return ok(fn(...args));
    } catch (cause) {
      return err(onError(cause));
    }
  };
}
