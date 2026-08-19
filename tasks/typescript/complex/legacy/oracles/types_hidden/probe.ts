import { DISCOUNTS, PRODUCTS, discountFor, findProduct } from "../src/catalog";
import type { Discount, Product } from "../src/catalog";
import { applyDiscount, priceLine } from "../src/pricing";
import type { OrderLine, PricedLine } from "../src/pricing";
import {
  adjustmentValue,
  assertNever,
  buildReceipt,
  priceOrder,
} from "../src/orders";
import type { Adjustment, Order, PricedOrder } from "../src/orders";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _Product = Expect<
  Equals<
    Product,
    { sku: string; name: string; priceCents: number; category: string }
  >
>;
type _Discount = Expect<Equals<Discount, { sku: string; percent: number }>>;
type _Products = Expect<Equals<typeof PRODUCTS, readonly Product[]>>;
type _Discounts = Expect<Equals<typeof DISCOUNTS, readonly Discount[]>>;
type _Find = Expect<Equals<ReturnType<typeof findProduct>, Product | undefined>>;
type _DiscountFor = Expect<Equals<ReturnType<typeof discountFor>, Discount | null>>;

type _OrderLine = Expect<Equals<OrderLine, { sku: string; qty: number }>>;
type _PricedLine = Expect<
  Equals<
    PricedLine,
    {
      sku: string;
      name: string;
      category: string;
      qty: number;
      grossCents: number;
      netCents: number;
    }
  >
>;
type _PriceLine = Expect<Equals<ReturnType<typeof priceLine>, PricedLine | null>>;
type _Apply = Expect<
  Equals<typeof applyDiscount, (sku: string, grossCents: number) => number>
>;

type _AdjustmentKinds = Expect<Equals<Adjustment["kind"], "credit" | "fee" | "tax">>;
type _Credit = Expect<
  Equals<Extract<Adjustment, { kind: "credit" }>, { kind: "credit"; cents: number }>
>;
type _Fee = Expect<
  Equals<
    Extract<Adjustment, { kind: "fee" }>,
    { kind: "fee"; cents: number; reason: string }
  >
>;
type _Tax = Expect<
  Equals<Extract<Adjustment, { kind: "tax" }>, { kind: "tax"; rate: number }>
>;
type _Order = Expect<
  Equals<Order, { id: string; items: OrderLine[]; adjustments: Adjustment[] }>
>;
type _PricedOrder = Expect<
  Equals<
    PricedOrder,
    {
      id: string;
      lines: PricedLine[];
      rejected: string[];
      adjustments: Adjustment[];
      subtotalCents: number;
      adjustmentCents: number;
      totalCents: number;
    }
  >
>;
type _Never = Expect<Equals<Parameters<typeof assertNever>[0], never>>;
type _AdjustmentValue = Expect<
  Equals<typeof adjustmentValue, (adjustment: Adjustment, subtotalCents: number) => number>
>;
type _PriceOrder = Expect<Equals<ReturnType<typeof priceOrder>, PricedOrder>>;
type _Receipt = Expect<Equals<ReturnType<typeof buildReceipt>, string[]>>;

// a lookup result must be checked before it is used
const found = findProduct("BK-1");
// @ts-expect-error the product may be missing
void found.name;
if (found !== undefined) {
  const name: string = found.name;
  void name;
}

const discount = discountFor("BK-1");
// @ts-expect-error the discount may be null
void discount.percent;
if (discount !== null) {
  const percent: number = discount.percent;
  void percent;
}

const line = priceLine({ sku: "BK-1", qty: 1 });
// @ts-expect-error the line may be null
void line.netCents;

// @ts-expect-error a line item needs a quantity
priceLine({ sku: "BK-1" });

// @ts-expect-error the quantity is a number
priceLine({ sku: "BK-1", qty: "1" });

declare const adjustment: Adjustment;
if (adjustment.kind === "fee") {
  const reason: string = adjustment.reason;
  void reason;
  // @ts-expect-error a fee has no rate
  void adjustment.rate;
} else if (adjustment.kind === "tax") {
  const rate: number = adjustment.rate;
  void rate;
  // @ts-expect-error a tax has no cents
  void adjustment.cents;
}

// @ts-expect-error "rebate" is not an adjustment kind
adjustmentValue({ kind: "rebate", cents: 1 }, 0);

// @ts-expect-error a fee carries a reason
adjustmentValue({ kind: "fee", cents: 1 }, 0);

// @ts-expect-error a tax carries a rate, not cents
adjustmentValue({ kind: "tax", cents: 1 }, 0);

function neverProbe(): never {
  // @ts-expect-error assertNever only accepts a proved-impossible value
  return assertNever({ kind: "rebate" });
}
void neverProbe;

// @ts-expect-error an order needs its adjustments
priceOrder({ id: "A", items: [] });

// @ts-expect-error buildReceipt takes a priced order
buildReceipt({ id: "A", items: [], adjustments: [] });

const priced: PricedOrder = priceOrder({ id: "A", items: [], adjustments: [] });
const receipt: string[] = buildReceipt(priced);
void receipt;
// @ts-expect-error the priced order has no such field
void priced.currency;

export type {
  _Product,
  _Discount,
  _Products,
  _Discounts,
  _Find,
  _DiscountFor,
  _OrderLine,
  _PricedLine,
  _PriceLine,
  _Apply,
  _AdjustmentKinds,
  _Credit,
  _Fee,
  _Tax,
  _Order,
  _PricedOrder,
  _Never,
  _AdjustmentValue,
  _PriceOrder,
  _Receipt,
};
