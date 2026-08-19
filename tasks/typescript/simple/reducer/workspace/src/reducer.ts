/**
 * Shopping-cart state.
 *
 * The action type below is a placeholder: it compiles, but it describes
 * every action as "an object with a string `type`", which is not the
 * shape the reducer is supposed to see.
 */
export interface CartItem {
  sku: string;
  qty: number;
  unitPrice: number;
}

export interface CartState {
  items: CartItem[];
  coupon: string | null;
}

export type CartAction = { type: string; [field: string]: unknown };

export type CartActionType = string;

export const initialState: CartState = { items: [], coupon: null };

export function assertNever(value: unknown): never {
  throw new Error("assertNever is not implemented: " + String(value));
}

export function reducer(state: CartState, action: CartAction): CartState {
  void state;
  void action;
  throw new Error("reducer is not implemented");
}

export function total(state: CartState): number {
  void state;
  throw new Error("total is not implemented");
}
