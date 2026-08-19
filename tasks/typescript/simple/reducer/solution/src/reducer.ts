/** Shopping-cart state, actions, and a pure reducer over them. */
export interface CartItem {
  sku: string;
  qty: number;
  unitPrice: number;
}

export interface CartState {
  items: CartItem[];
  coupon: string | null;
}

export type CartAction =
  | { type: "add"; sku: string; qty: number; unitPrice: number }
  | { type: "remove"; sku: string }
  | { type: "setQty"; sku: string; qty: number }
  | { type: "applyCoupon"; code: string }
  | { type: "clearCoupon" }
  | { type: "clear" };

export type CartActionType = CartAction["type"];

export const initialState: CartState = { items: [], coupon: null };

export function assertNever(value: never): never {
  throw new Error("unhandled variant: " + JSON.stringify(value));
}

export function reducer(state: CartState, action: CartAction): CartState {
  switch (action.type) {
    case "add": {
      if (action.qty < 1) return state;
      const i = state.items.findIndex((it) => it.sku === action.sku);
      if (i < 0) {
        return {
          ...state,
          items: [
            ...state.items,
            { sku: action.sku, qty: action.qty, unitPrice: action.unitPrice },
          ],
        };
      }
      const existing = state.items[i] as CartItem;
      const items = state.items.slice();
      items[i] = {
        sku: existing.sku,
        qty: existing.qty + action.qty,
        unitPrice: action.unitPrice,
      };
      return { ...state, items };
    }
    case "remove": {
      const i = state.items.findIndex((it) => it.sku === action.sku);
      if (i < 0) return state;
      const items = state.items.slice();
      items.splice(i, 1);
      return { ...state, items };
    }
    case "setQty": {
      const i = state.items.findIndex((it) => it.sku === action.sku);
      if (i < 0) return state;
      const existing = state.items[i] as CartItem;
      if (action.qty <= 0) {
        const items = state.items.slice();
        items.splice(i, 1);
        return { ...state, items };
      }
      if (existing.qty === action.qty) return state;
      const items = state.items.slice();
      items[i] = { sku: existing.sku, qty: action.qty, unitPrice: existing.unitPrice };
      return { ...state, items };
    }
    case "applyCoupon": {
      const code = action.code.trim().toUpperCase();
      if (code === "") return state;
      if (state.coupon === code) return state;
      return { ...state, coupon: code };
    }
    case "clearCoupon": {
      if (state.coupon === null) return state;
      return { ...state, coupon: null };
    }
    case "clear": {
      if (state.items.length === 0 && state.coupon === null) return state;
      return { items: [], coupon: null };
    }
    default:
      return assertNever(action);
  }
}

export function total(state: CartState): number {
  let sum = 0;
  for (const item of state.items) {
    sum += item.qty * item.unitPrice;
  }
  if (state.coupon === "SAVE10") {
    sum = sum * 0.9;
  } else if (state.coupon === "SAVE5") {
    sum = Math.max(0, sum - 5);
  }
  return Math.round((sum + Number.EPSILON) * 100) / 100;
}
