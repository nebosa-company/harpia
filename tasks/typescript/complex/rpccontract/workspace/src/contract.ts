/**
 * The shared contract.
 *
 * The declarations below are placeholders. A procedure has forgotten
 * what it takes and what it returns, so both sides of the wire are back
 * to passing `unknown` around and casting.
 */
export type Parser<T> = (value: unknown) => T;

export interface Procedure<I, O> {
  readonly name: string;
  readonly input: Parser<unknown>;
  readonly output: Parser<unknown>;
}

export type Contract = Record<string, Procedure<unknown, unknown>>;

export type InputOf<P> = unknown;

export type OutputOf<P> = unknown;

function unimplemented(name: string): never {
  throw new Error(`${name} is not implemented`);
}

export function procedure(
  name: string,
  input: Parser<unknown>,
  output: Parser<unknown>,
): Procedure<unknown, unknown> {
  void name;
  void input;
  void output;
  return unimplemented("procedure");
}

export function asString(value: unknown): string {
  void value;
  return unimplemented("asString");
}

export function asNumber(value: unknown): number {
  void value;
  return unimplemented("asNumber");
}

export function asBoolean(value: unknown): boolean {
  void value;
  return unimplemented("asBoolean");
}

export function asLiteral(literal: string | number | boolean): Parser<unknown> {
  void literal;
  return unimplemented("asLiteral");
}

export function asArray(item: Parser<unknown>): Parser<unknown> {
  void item;
  return unimplemented("asArray");
}

export function asObject(fields: Record<string, Parser<unknown>>): Parser<unknown> {
  void fields;
  return unimplemented("asObject");
}

export function asOptional(inner: Parser<unknown>): Parser<unknown> {
  void inner;
  return unimplemented("asOptional");
}
