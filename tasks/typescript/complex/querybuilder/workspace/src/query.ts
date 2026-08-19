/**
 * A tiny in-memory query builder.
 *
 * The declarations below are placeholders. They compile, but the query
 * has forgotten which table it is reading and which columns were
 * selected, so `run()` hands back untyped rows.
 */
export type Cell = string | number | boolean | null;

export type Row = Record<string, Cell>;

export type Schema = Record<string, Row>;

export type Rows<S extends Schema> = { [T in keyof S]: S[T][] };

export type Operator = "=" | "!=" | "<" | "<=" | ">" | ">=";

export type Direction = "asc" | "desc";

export interface Query<
  S extends Schema,
  T extends keyof S & string,
  K extends keyof S[T] & string,
> {
  select(...columns: string[]): Query<S, T, K>;
  where(column: string, op: Operator, value: Cell): Query<S, T, K>;
  orderBy(column: string, direction?: Direction): Query<S, T, K>;
  limit(count: number): Query<S, T, K>;
  offset(count: number): Query<S, T, K>;
  toSql(): string;
  run(): Row[];
}

export interface Database<S extends Schema> {
  from<T extends keyof S & string>(table: T): Query<S, T, keyof S[T] & string>;
}

export function createDatabase<S extends Schema>(rows: Rows<S>): Database<S> {
  void rows;
  throw new Error("createDatabase is not implemented");
}
