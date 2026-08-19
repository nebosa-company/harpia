/**
 * Hand-rolled routing.
 *
 * The two type aliases below are placeholders: they compile, but they
 * throw away the pattern and describe every route as "some strings",
 * which is exactly what the call sites are not supposed to see.
 */
export type ParamName<P extends string> = string;

export type PathParams<P extends string> = Record<string, string>;

export function matchRoute<P extends string>(
  pattern: P,
  path: string,
): PathParams<P> | null {
  void pattern;
  void path;
  throw new Error("matchRoute is not implemented");
}

export function buildPath<P extends string>(pattern: P, params: PathParams<P>): string {
  void pattern;
  void params;
  throw new Error("buildPath is not implemented");
}

export function paramNames<P extends string>(pattern: P): ParamName<P>[] {
  void pattern;
  throw new Error("paramNames is not implemented");
}
