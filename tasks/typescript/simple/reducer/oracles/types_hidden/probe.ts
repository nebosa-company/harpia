import { assertNever, reducer, total, initialState } from "../src/reducer";
import type { CartAction, CartActionType, CartState } from "../src/reducer";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _ActionTypes = Expect<
  Equals<
    CartActionType,
    "add" | "remove" | "setQty" | "applyCoupon" | "clearCoupon" | "clear"
  >
>;

type _Add = Expect<
  Equals<
    Extract<CartAction, { type: "add" }>,
    { type: "add"; sku: string; qty: number; unitPrice: number }
  >
>;
type _Remove = Expect<Equals<Extract<CartAction, { type: "remove" }>, { type: "remove"; sku: string }>>;
type _ClearCoupon = Expect<Equals<Extract<CartAction, { type: "clearCoupon" }>, { type: "clearCoupon" }>>;
type _Never = Expect<Equals<Parameters<typeof assertNever>[0], never>>;
type _Reducer = Expect<Equals<ReturnType<typeof reducer>, CartState>>;
type _Total = Expect<Equals<ReturnType<typeof total>, number>>;

declare const s: CartState;

reducer(s, { type: "add", sku: "a", qty: 1, unitPrice: 2 });
reducer(s, { type: "remove", sku: "a" });
reducer(s, { type: "setQty", sku: "a", qty: 1 });
reducer(s, { type: "applyCoupon", code: "X" });
reducer(s, { type: "clearCoupon" });
reducer(s, { type: "clear" });

// @ts-expect-error "teleport" is not a member of the action union
reducer(s, { type: "teleport" });

// @ts-expect-error "add" needs a unitPrice
reducer(s, { type: "add", sku: "a", qty: 1 });

// @ts-expect-error "remove" has no qty
reducer(s, { type: "remove", sku: "a", qty: 1 });

// @ts-expect-error "clear" carries no payload
reducer(s, { type: "clear", sku: "a" });

// @ts-expect-error qty is a number
reducer(s, { type: "setQty", sku: "a", qty: "1" });

function neverProbe(): never {
  // @ts-expect-error assertNever only accepts a proved-impossible value
  return assertNever("still a string");
}
void neverProbe;

// narrowing on the discriminant reaches the right member
declare const a: CartAction;
if (a.type === "add") {
  const price: number = a.unitPrice;
  void price;
} else if (a.type === "applyCoupon") {
  const code: string = a.code;
  void code;
  // @ts-expect-error applyCoupon carries no sku
  void a.sku;
}

// the initial state is a CartState, not a wider record
const init: CartState = initialState;
void init;
// @ts-expect-error CartState has no such field
void initialState.discount;

export type { _ActionTypes, _Add, _Remove, _ClearCoupon, _Never, _Reducer, _Total };
