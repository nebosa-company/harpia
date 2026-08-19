/** A tiny in-memory query builder whose row type follows the selection. */
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
  select<C extends readonly (keyof S[T] & string)[]>(
    ...columns: C
  ): Query<S, T, C[number]>;
  where<F extends keyof S[T] & string>(
    column: F,
    op: Operator,
    value: S[T][F],
  ): Query<S, T, K>;
  orderBy(column: keyof S[T] & string, direction?: Direction): Query<S, T, K>;
  limit(count: number): Query<S, T, K>;
  offset(count: number): Query<S, T, K>;
  toSql(): string;
  run(): Pick<S[T], K>[];
}

export interface Database<S extends Schema> {
  from<T extends keyof S & string>(table: T): Query<S, T, keyof S[T] & string>;
}

interface Condition {
  column: string;
  op: Operator;
  value: Cell;
}

interface Sort {
  column: string;
  direction: Direction;
}

interface Plan {
  table: string;
  columns: string[] | null;
  conditions: Condition[];
  sorts: Sort[];
  limit: number | null;
  offset: number | null;
}

function literal(value: Cell): string {
  if (value === null) return "NULL";
  if (typeof value === "string") return `'${value.replaceAll("'", "''")}'`;
  if (typeof value === "boolean") return value ? "TRUE" : "FALSE";
  return String(value);
}

function condition(c: Condition): string {
  if (c.value === null && c.op === "=") return `${c.column} IS NULL`;
  if (c.value === null && c.op === "!=") return `${c.column} IS NOT NULL`;
  return `${c.column} ${c.op} ${literal(c.value)}`;
}

function matches(row: Row, c: Condition): boolean {
  const left = row[c.column] as Cell;
  const right = c.value;
  switch (c.op) {
    case "=":
      return left === right;
    case "!=":
      return left !== right;
    case "<":
      return (left as never) < (right as never);
    case "<=":
      return (left as never) <= (right as never);
    case ">":
      return (left as never) > (right as never);
    case ">=":
      return (left as never) >= (right as never);
    default:
      return false;
  }
}

function compareCells(a: Cell, b: Cell): number {
  if (typeof a === "number" && typeof b === "number") return a - b;
  if (typeof a === "string" && typeof b === "string") return a < b ? -1 : a > b ? 1 : 0;
  if (typeof a === "boolean" && typeof b === "boolean") {
    return (a ? 1 : 0) - (b ? 1 : 0);
  }
  return 0;
}

function makeQuery<
  S extends Schema,
  T extends keyof S & string,
  K extends keyof S[T] & string,
>(source: Record<string, Row[] | undefined>, plan: Plan): Query<S, T, K> {
  const next = <N extends keyof S[T] & string>(patch: Partial<Plan>): Query<S, T, N> =>
    makeQuery<S, T, N>(source, { ...plan, ...patch });

  return {
    select<C extends readonly (keyof S[T] & string)[]>(
      ...columns: C
    ): Query<S, T, C[number]> {
      return next<C[number]>({ columns: [...columns] as string[] });
    },

    where<F extends keyof S[T] & string>(
      column: F,
      op: Operator,
      value: S[T][F],
    ): Query<S, T, K> {
      return next<K>({
        conditions: [...plan.conditions, { column, op, value: value as Cell }],
      });
    },

    orderBy(column: keyof S[T] & string, direction: Direction = "asc"): Query<S, T, K> {
      return next<K>({ sorts: [...plan.sorts, { column, direction }] });
    },

    limit(count: number): Query<S, T, K> {
      return next<K>({ limit: count });
    },

    offset(count: number): Query<S, T, K> {
      return next<K>({ offset: count });
    },

    toSql(): string {
      const parts: string[] = [
        `SELECT ${plan.columns === null ? "*" : plan.columns.join(", ")}`,
        `FROM ${plan.table}`,
      ];
      if (plan.conditions.length > 0) {
        parts.push(`WHERE ${plan.conditions.map(condition).join(" AND ")}`);
      }
      if (plan.sorts.length > 0) {
        const rendered = plan.sorts
          .map((s) => `${s.column} ${s.direction.toUpperCase()}`)
          .join(", ");
        parts.push(`ORDER BY ${rendered}`);
      }
      if (plan.limit !== null) parts.push(`LIMIT ${plan.limit}`);
      if (plan.offset !== null) parts.push(`OFFSET ${plan.offset}`);
      return parts.join(" ");
    },

    run(): Pick<S[T], K>[] {
      const table = source[plan.table];
      if (table === undefined) {
        throw new RangeError(`unknown table: ${plan.table}`);
      }
      let out = table.filter((row) => plan.conditions.every((c) => matches(row, c)));
      if (plan.sorts.length > 0) {
        out = out
          .map((row, index) => ({ row, index }))
          .sort((a, b) => {
            for (const sort of plan.sorts) {
              const raw = compareCells(a.row[sort.column] as Cell, b.row[sort.column] as Cell);
              const signed = sort.direction === "desc" ? -raw : raw;
              if (signed !== 0) return signed;
            }
            return a.index - b.index;
          })
          .map((entry) => entry.row);
      }
      if (plan.offset !== null) out = out.slice(plan.offset);
      if (plan.limit !== null) out = out.slice(0, plan.limit);
      return out.map((row) => {
        const keys = plan.columns ?? Object.keys(row);
        const projected: Row = {};
        for (const key of keys) {
          projected[key] = row[key] as Cell;
        }
        return projected as Pick<S[T], K>;
      });
    },
  };
}

export function createDatabase<S extends Schema>(rows: Rows<S>): Database<S> {
  const source = rows as unknown as Record<string, Row[] | undefined>;
  return {
    from<T extends keyof S & string>(table: T): Query<S, T, keyof S[T] & string> {
      return makeQuery<S, T, keyof S[T] & string>(source, {
        table,
        columns: null,
        conditions: [],
        sorts: [],
        limit: null,
        offset: null,
      });
    },
  };
}
