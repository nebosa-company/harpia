/** A very small schema validator whose output types are inferred. */
export interface Issue {
  path: (string | number)[];
  message: string;
}

export type ParseResult<T> = { ok: true; value: T } | { ok: false; issues: Issue[] };

export interface Schema<T> {
  parse(value: unknown): ParseResult<T>;
}

export type Infer<S> = S extends Schema<infer T> ? T : never;

type Shape = Record<string, Schema<unknown>>;

type Simplify<T> = { [K in keyof T]: T[K] };

type OptionalKeys<S extends Shape> = {
  [K in keyof S]: undefined extends Infer<S[K]> ? K : never;
}[keyof S];

type RequiredKeys<S extends Shape> = Exclude<keyof S, OptionalKeys<S>>;

export type ObjectOutput<S extends Shape> = Simplify<
  { [K in RequiredKeys<S>]: Infer<S[K]> } & { [K in OptionalKeys<S>]?: Infer<S[K]> }
>;

const good = <T>(value: T): ParseResult<T> => ({ ok: true, value });
const bad = (message: string): ParseResult<never> => ({
  ok: false,
  issues: [{ path: [], message }],
});
const prefix = (issues: Issue[], head: string | number): Issue[] =>
  issues.map((issue) => ({ path: [head, ...issue.path], message: issue.message }));

const primitive = <T>(check: (value: unknown) => boolean, message: string): Schema<T> => ({
  parse(value: unknown): ParseResult<T> {
    return check(value) ? good(value as T) : bad(message);
  },
});

export const s = {
  string(): Schema<string> {
    return primitive<string>((v) => typeof v === "string", "expected string");
  },

  number(): Schema<number> {
    return primitive<number>(
      (v) => typeof v === "number" && Number.isFinite(v),
      "expected number",
    );
  },

  boolean(): Schema<boolean> {
    return primitive<boolean>((v) => typeof v === "boolean", "expected boolean");
  },

  literal<L extends string | number | boolean>(value: L): Schema<L> {
    const message = `expected literal ${JSON.stringify(value)}`;
    return {
      parse(input: unknown): ParseResult<L> {
        return input === value ? good(value) : bad(message);
      },
    };
  },

  array<T>(item: Schema<T>): Schema<T[]> {
    return {
      parse(value: unknown): ParseResult<T[]> {
        if (!Array.isArray(value)) return bad("expected array");
        const out: T[] = [];
        const issues: Issue[] = [];
        value.forEach((element, index) => {
          const result = item.parse(element);
          if (result.ok) {
            out.push(result.value);
          } else {
            issues.push(...prefix(result.issues, index));
          }
        });
        return issues.length > 0 ? { ok: false, issues } : { ok: true, value: out };
      },
    };
  },

  optional<T>(inner: Schema<T>): Schema<T | undefined> {
    return {
      parse(value: unknown): ParseResult<T | undefined> {
        if (value === undefined) return good(undefined);
        return inner.parse(value);
      },
    };
  },

  union<A, B>(a: Schema<A>, b: Schema<B>): Schema<A | B> {
    return {
      parse(value: unknown): ParseResult<A | B> {
        const first = a.parse(value);
        if (first.ok) return first;
        const second = b.parse(value);
        if (second.ok) return second;
        return bad("no union member matched");
      },
    };
  },

  object<S extends Shape>(shape: S): Schema<ObjectOutput<S>> {
    return {
      parse(value: unknown): ParseResult<ObjectOutput<S>> {
        if (typeof value !== "object" || value === null || Array.isArray(value)) {
          return bad("expected object");
        }
        const source = value as Record<string, unknown>;
        const out: Record<string, unknown> = {};
        const issues: Issue[] = [];
        for (const key of Object.keys(shape)) {
          const field = shape[key] as Schema<unknown>;
          const result = field.parse(source[key]);
          if (!result.ok) {
            issues.push(...prefix(result.issues, key));
            continue;
          }
          if (result.value !== undefined) {
            out[key] = result.value;
          }
        }
        return issues.length > 0
          ? { ok: false, issues }
          : { ok: true, value: out as ObjectOutput<S> };
      },
    };
  },
};
