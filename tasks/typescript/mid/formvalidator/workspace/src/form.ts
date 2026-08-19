/**
 * Form validation driven by the shape of the values.
 *
 * The type aliases below are placeholders. They compile, but they
 * describe every rule table as "some validators keyed by some strings",
 * so a forgotten field or a mismatched validator sails straight through.
 */
export type Validator<T> = (value: T) => string | null;

export type Rules<T> = Record<string, Validator<unknown>[]>;

export type Errors<T> = Record<string, string>;

export type FieldName<T> = string;

export function validate<T extends object>(values: T, rules: Rules<T>): Errors<T> {
  void values;
  void rules;
  throw new Error("validate is not implemented");
}

export function isValid<T extends object>(errors: Errors<T>): boolean {
  void errors;
  throw new Error("isValid is not implemented");
}

export function firstError<T extends object>(
  errors: Errors<T>,
  order: readonly FieldName<T>[],
): string | null {
  void errors;
  void order;
  throw new Error("firstError is not implemented");
}

export const rules = {
  required(message?: string): Validator<unknown> {
    void message;
    throw new Error("rules.required is not implemented");
  },
  minLength(n: number, message?: string): Validator<string> {
    void n;
    void message;
    throw new Error("rules.minLength is not implemented");
  },
  maxLength(n: number, message?: string): Validator<string> {
    void n;
    void message;
    throw new Error("rules.maxLength is not implemented");
  },
  pattern(re: RegExp, message?: string): Validator<string> {
    void re;
    void message;
    throw new Error("rules.pattern is not implemented");
  },
  range(min: number, max: number, message?: string): Validator<number> {
    void min;
    void max;
    void message;
    throw new Error("rules.range is not implemented");
  },
  isTrue(message?: string): Validator<boolean> {
    void message;
    throw new Error("rules.isTrue is not implemented");
  },
};
