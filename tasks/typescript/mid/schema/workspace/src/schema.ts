/**
 * A very small schema validator.
 *
 * The declarations below are placeholders. They compile, but every
 * builder claims to produce `Schema<unknown>`, so `Infer` gives nothing
 * useful and every call site would need a cast.
 */
export interface Issue {
  path: (string | number)[];
  message: string;
}

export type ParseResult<T> = { ok: true; value: T } | { ok: false; issues: Issue[] };

export interface Schema<T> {
  parse(value: unknown): ParseResult<T>;
}

export type Infer<S> = unknown;

function unimplemented(name: string): never {
  throw new Error(`${name} is not implemented`);
}

export const s = {
  string(): Schema<unknown> {
    return unimplemented("s.string");
  },
  number(): Schema<unknown> {
    return unimplemented("s.number");
  },
  boolean(): Schema<unknown> {
    return unimplemented("s.boolean");
  },
  literal(value: string | number | boolean): Schema<unknown> {
    void value;
    return unimplemented("s.literal");
  },
  array(item: Schema<unknown>): Schema<unknown> {
    void item;
    return unimplemented("s.array");
  },
  optional(inner: Schema<unknown>): Schema<unknown> {
    void inner;
    return unimplemented("s.optional");
  },
  union(a: Schema<unknown>, b: Schema<unknown>): Schema<unknown> {
    void a;
    void b;
    return unimplemented("s.union");
  },
  object(shape: Record<string, Schema<unknown>>): Schema<unknown> {
    void shape;
    return unimplemented("s.object");
  },
};
