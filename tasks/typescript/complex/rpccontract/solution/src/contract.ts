/** The shared contract: procedures, and the parsers that guard them. */
export type Parser<T> = (value: unknown) => T;

export interface Procedure<I, O> {
  readonly name: string;
  readonly input: Parser<I>;
  readonly output: Parser<O>;
}

export type Contract = Record<string, Procedure<unknown, unknown>>;

export type InputOf<P> = P extends Procedure<infer I, unknown> ? I : never;

export type OutputOf<P> = P extends Procedure<unknown, infer O> ? O : never;

export function procedure<I, O>(
  name: string,
  input: Parser<I>,
  output: Parser<O>,
): Procedure<I, O> {
  return { name, input, output };
}

export function asString(value: unknown): string {
  if (typeof value !== "string") throw new TypeError("expected string");
  return value;
}

export function asNumber(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new TypeError("expected number");
  }
  return value;
}

export function asBoolean(value: unknown): boolean {
  if (typeof value !== "boolean") throw new TypeError("expected boolean");
  return value;
}

export function asLiteral<L extends string | number | boolean>(literal: L): Parser<L> {
  const message = `expected literal ${JSON.stringify(literal)}`;
  return (value: unknown): L => {
    if (value !== literal) throw new TypeError(message);
    return literal;
  };
}

function messageOf(cause: unknown): string {
  return cause instanceof Error ? cause.message : String(cause);
}

export function asArray<T>(item: Parser<T>): Parser<T[]> {
  return (value: unknown): T[] => {
    if (!Array.isArray(value)) throw new TypeError("expected array");
    return value.map((element, index) => {
      try {
        return item(element);
      } catch (cause) {
        throw new TypeError(`[${index}] ${messageOf(cause)}`);
      }
    });
  };
}

export function asObject<F extends Record<string, Parser<unknown>>>(
  fields: F,
): Parser<{ [K in keyof F]: ReturnType<F[K]> }> {
  return (value: unknown): { [K in keyof F]: ReturnType<F[K]> } => {
    if (typeof value !== "object" || value === null || Array.isArray(value)) {
      throw new TypeError("expected object");
    }
    const source = value as Record<string, unknown>;
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(fields)) {
      const parse = fields[key] as Parser<unknown>;
      let parsed: unknown;
      try {
        parsed = parse(source[key]);
      } catch (cause) {
        throw new TypeError(`${key} ${messageOf(cause)}`);
      }
      if (parsed !== undefined) out[key] = parsed;
    }
    return out as { [K in keyof F]: ReturnType<F[K]> };
  };
}

export function asOptional<T>(inner: Parser<T>): Parser<T | undefined> {
  return (value: unknown): T | undefined =>
    value === undefined ? undefined : inner(value);
}
