/** Form validation driven by the shape of the values. */
export type Validator<T> = (value: T) => string | null;

export type Rules<T> = { [K in keyof T]-?: Validator<T[K]>[] };

export type Errors<T> = { [K in keyof T]?: string };

export type FieldName<T> = keyof T & string;

export function validate<T extends object>(values: T, rules: Rules<T>): Errors<T> {
  const table = rules as Record<string, Validator<unknown>[]>;
  const source = values as Record<string, unknown>;
  const out: Record<string, string> = {};
  for (const key of Object.keys(table)) {
    const validators = table[key] ?? [];
    for (const check of validators) {
      const message = check(source[key]);
      if (message !== null) {
        out[key] = message;
        break;
      }
    }
  }
  return out as Errors<T>;
}

export function isValid<T extends object>(errors: Errors<T>): boolean {
  const table = errors as Record<string, string | undefined>;
  return Object.keys(table).every((key) => table[key] === undefined);
}

export function firstError<T extends object>(
  errors: Errors<T>,
  order: readonly FieldName<T>[],
): string | null {
  const table = errors as Record<string, string | undefined>;
  for (const key of order) {
    const message = table[key];
    if (message !== undefined) return message;
  }
  return null;
}

export const rules = {
  required(message = "required"): Validator<unknown> {
    return (value: unknown): string | null => {
      if (value === undefined || value === null) return message;
      if (typeof value === "string" && value.trim() === "") return message;
      return null;
    };
  },

  minLength(n: number, message = `must be at least ${n} characters`): Validator<string> {
    return (value: string): string | null => (value.length < n ? message : null);
  },

  maxLength(n: number, message = `must be at most ${n} characters`): Validator<string> {
    return (value: string): string | null => (value.length > n ? message : null);
  },

  pattern(re: RegExp, message = "invalid format"): Validator<string> {
    const flags = re.flags.replace(/[gy]/g, "");
    const stable = new RegExp(re.source, flags);
    return (value: string): string | null => (stable.test(value) ? null : message);
  },

  range(
    min: number,
    max: number,
    message = `must be between ${min} and ${max}`,
  ): Validator<number> {
    return (value: number): string | null =>
      Number.isNaN(value) || value < min || value > max ? message : null;
  },

  isTrue(message = "must be accepted"): Validator<boolean> {
    return (value: boolean): string | null => (value === true ? null : message);
  },
};
