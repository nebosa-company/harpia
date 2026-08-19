import { buildPath, matchRoute, paramNames } from "../src/route";
import type { ParamName, PathParams } from "../src/route";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _Names = Expect<Equals<ParamName<"/users/:id/posts/:postId">, "id" | "postId">>;
type _NoNames = Expect<Equals<ParamName<"/health">, never>>;
type _OneName = Expect<Equals<ParamName<"/:only">, "only">>;

type _Params = Expect<
  Equals<PathParams<"/users/:id/posts/:postId">, { id: string; postId: string }>
>;
type _Empty = Expect<Equals<PathParams<"/health">, {}>>;

const matched = matchRoute("/users/:id/posts/:postId", "/users/1/posts/2");
type _Match = Expect<Equals<typeof matched, { id: string; postId: string } | null>>;

if (matched !== null) {
  const id: string = matched.id;
  const postId: string = matched.postId;
  void id;
  void postId;
  // @ts-expect-error this route has no "slug" parameter
  void matched.slug;
}

const names = paramNames("/users/:id/posts/:postId");
type _NamesArray = Expect<Equals<typeof names, ("id" | "postId")[]>>;
const emptyNames = paramNames("/health");
type _EmptyNames = Expect<Equals<typeof emptyNames, never[]>>;

buildPath("/users/:id/posts/:postId", { id: "1", postId: "2" });
buildPath("/health", {});

// @ts-expect-error postId is missing
buildPath("/users/:id/posts/:postId", { id: "1" });

// @ts-expect-error "slug" is not a parameter of this route
buildPath("/users/:id", { id: "1", slug: "x" });

// @ts-expect-error parameter values are strings
buildPath("/users/:id", { id: 1 });

declare const wrongShape: { id: string };
// @ts-expect-error this route needs both parameters
buildPath("/users/:id/posts/:postId", wrongShape);

export type {
  _Names,
  _NoNames,
  _OneName,
  _Params,
  _Empty,
  _Match,
  _NamesArray,
  _EmptyNames,
};
