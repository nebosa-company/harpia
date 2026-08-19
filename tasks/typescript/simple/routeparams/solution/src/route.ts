/** Hand-rolled routing, with the parameter names read off the pattern. */
export type ParamName<P extends string> = P extends `${string}:${infer Rest}`
  ? Rest extends `${infer Name}/${infer Tail}`
    ? Name | ParamName<Tail>
    : Rest
  : never;

export type PathParams<P extends string> = { [K in ParamName<P>]: string };

const segmentsOf = (value: string): string[] => {
  const trimmed = value.length > 1 && value.endsWith("/") ? value.slice(0, -1) : value;
  return trimmed.split("/");
};

export function matchRoute<P extends string>(
  pattern: P,
  path: string,
): PathParams<P> | null {
  const want = segmentsOf(pattern);
  const got = segmentsOf(path);
  if (want.length !== got.length) return null;
  const out: Record<string, string> = {};
  for (let i = 0; i < want.length; i += 1) {
    const w = want[i] as string;
    const g = got[i] as string;
    if (w.startsWith(":")) {
      if (g === "") return null;
      out[w.slice(1)] = decodeURIComponent(g);
    } else if (w !== g) {
      return null;
    }
  }
  return out as PathParams<P>;
}

export function buildPath<P extends string>(pattern: P, params: PathParams<P>): string {
  const bag = params as Record<string, string | undefined>;
  return segmentsOf(pattern)
    .map((segment) => {
      if (!segment.startsWith(":")) return segment;
      const name = segment.slice(1);
      const value = bag[name];
      if (value === undefined || value === "") {
        throw new TypeError(`missing route parameter "${name}"`);
      }
      return encodeURIComponent(value);
    })
    .join("/");
}

export function paramNames<P extends string>(pattern: P): ParamName<P>[] {
  return segmentsOf(pattern)
    .filter((segment) => segment.startsWith(":"))
    .map((segment) => segment.slice(1)) as ParamName<P>[];
}
