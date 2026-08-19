import {
  DISCOUNTS,
  applyDiscount,
  findDiscount,
  formatMoney,
  lineTotal,
  priceOrder,
  summarizeByCategory,
} from "../src/pricing";
import type {
  Currency,
  Discount,
  LineItem,
  PricedLine,
  PricedOrder,
} from "../src/pricing";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _Currency = Expect<Equals<Currency, "EUR" | "GBP" | "USD">>;
type _LineItem = Expect<
  Equals<
    LineItem,
    { sku: string; qty: number; unitCents: number; category: string }
  >
>;
type _Discount = Expect<
  Equals<Discount, { code: string; kind: "percent" | "fixed"; amount: number }>
>;
type _PricedLine = Expect<
  Equals<PricedLine, { sku: string; category: string; grossCents: number }>
>;
type _PricedOrder = Expect<
  Equals<
    PricedOrder,
    {
      lines: PricedLine[];
      subtotalCents: number;
      discountCents: number;
      totalCents: number;
      currency: Currency;
    }
  >
>;

type _LineTotal = Expect<Equals<typeof lineTotal, (item: LineItem) => number>>;
type _Find = Expect<Equals<ReturnType<typeof findDiscount>, Discount | undefined>>;
type _Apply = Expect<
  Equals<typeof applyDiscount, (subtotalCents: number, code: string | null) => number>
>;
type _Price = Expect<Equals<ReturnType<typeof priceOrder>, PricedOrder>>;
type _Format = Expect<
  Equals<typeof formatMoney, (cents: number, currency: Currency) => string>
>;
type _Summary = Expect<
  Equals<
    ReturnType<typeof summarizeByCategory>,
    Array<{ category: string; grossCents: number; share: number }>
  >
>;
type _Discounts = Expect<Equals<typeof DISCOUNTS, readonly Discount[]>>;

const order = priceOrder([], null, "EUR");
const subtotal: number = order.subtotalCents;
const currency: Currency = order.currency;
void subtotal;
void currency;

// @ts-expect-error the priced order has no such field
void order.taxCents;

// @ts-expect-error "JPY" is not one of the supported currencies
priceOrder([], null, "JPY");

// @ts-expect-error "JPY" is not one of the supported currencies
formatMoney(1, "JPY");

// @ts-expect-error a line item needs every field
lineTotal({ sku: "a", qty: 1 });

// @ts-expect-error the quantity is a number
lineTotal({ sku: "a", qty: "1", unitCents: 1, category: "x" });

// @ts-expect-error the discount table is read-only
DISCOUNTS.push({ code: "X", kind: "fixed", amount: 1 });

// @ts-expect-error a discount kind is one of two literals
const badKind: Discount = { code: "X", kind: "coupon", amount: 1 };
void badKind;

// @ts-expect-error summarizeByCategory takes a priced order
summarizeByCategory({ lines: [] });

const first = DISCOUNTS[0];
const kind: "percent" | "fixed" = first.kind;
void kind;

export type {
  _Currency,
  _LineItem,
  _Discount,
  _PricedLine,
  _PricedOrder,
  _LineTotal,
  _Find,
  _Apply,
  _Price,
  _Format,
  _Summary,
  _Discounts,
};
