import { deepFreeze } from "../src/deep-readonly";
import type { DeepMutable, DeepReadonly } from "../src/deep-readonly";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

interface Node {
  id: string;
  meta: { tags: string[]; count?: number };
  children: Node[];
}

type _Primitives = Expect<
  Equals<
    [
      DeepReadonly<string>,
      DeepReadonly<number>,
      DeepReadonly<boolean>,
      DeepReadonly<null>,
      DeepReadonly<undefined>,
      DeepReadonly<bigint>,
    ],
    [string, number, boolean, null, undefined, bigint]
  >
>;

type _Fn = Expect<Equals<DeepReadonly<(a: number) => string>, (a: number) => string>>;
type _Date = Expect<Equals<DeepReadonly<Date>, Date>>;

type _Array = Expect<
  Equals<DeepReadonly<{ a: number[] }>, { readonly a: readonly number[] }>
>;

type _Tuple = Expect<
  Equals<DeepReadonly<[number, { b: string }]>, readonly [number, { readonly b: string }]>
>;

type _Map = Expect<
  Equals<
    DeepReadonly<Map<string, { v: number }>>,
    ReadonlyMap<string, { readonly v: number }>
  >
>;
type _Set = Expect<
  Equals<DeepReadonly<Set<{ v: number }>>, ReadonlySet<{ readonly v: number }>>
>;

type _Optional = Expect<
  Equals<
    DeepReadonly<{ a?: { b: string } }>,
    { readonly a?: { readonly b: string } }
  >
>;

type _Roundtrip = Expect<Equals<DeepMutable<DeepReadonly<Node>>, Node>>;
type _MutableArray = Expect<
  Equals<DeepMutable<{ readonly a: readonly number[] }>, { a: number[] }>
>;
type _MutableMap = Expect<
  Equals<DeepMutable<ReadonlyMap<string, ReadonlySet<number>>>, Map<string, Set<number>>>
>;

type _Freeze = Expect<Equals<ReturnType<typeof deepFreeze<Node>>, DeepReadonly<Node>>>;

declare const node: Node;
const frozen = deepFreeze(node);

const id: string = frozen.id;
const tag: string | undefined = frozen.meta.tags[0];
void id;
void tag;

// @ts-expect-error every level is readonly
frozen.id = "x";

// @ts-expect-error nested objects are readonly too
frozen.meta.count = 1;

// @ts-expect-error arrays become readonly arrays
frozen.meta.tags.push("x");

// @ts-expect-error readonly arrays cannot be index-assigned
frozen.children[0] = node;

// @ts-expect-error the readonly tree is not assignable back to the mutable one
const back: Node = frozen;
void back;

declare const roMap: DeepReadonly<Map<string, { v: number }>>;
// @ts-expect-error a ReadonlyMap has no set
roMap.set("a", { v: 1 });

declare const roSet: DeepReadonly<Set<number>>;
// @ts-expect-error a ReadonlySet has no add
roSet.add(1);

export type {
  _Primitives,
  _Fn,
  _Date,
  _Array,
  _Tuple,
  _Map,
  _Set,
  _Optional,
  _Roundtrip,
  _MutableArray,
  _MutableMap,
  _Freeze,
};
