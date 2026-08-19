import { amountOf, decode, summarize } from "../src/report";
import type { Entry, Summary } from "../src/report";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _Decode = Expect<Equals<ReturnType<typeof decode>, Entry | null>>;
type _AmountArg = Expect<Equals<Parameters<typeof amountOf>[0], Entry>>;
type _AmountRet = Expect<Equals<ReturnType<typeof amountOf>, number>>;
type _Summarize = Expect<Equals<ReturnType<typeof summarize>, Summary>>;
type _SummarizeArg = Expect<Equals<Parameters<typeof summarize>[0], readonly string[]>>;

const entry = decode("sale|1|eu");

if (entry !== null) {
  const kind: "sale" | "refund" | "adjustment" = entry.kind;
  void kind;
  if (entry.kind === "sale") {
    const region: string = entry.region;
    void region;
    // @ts-expect-error a sale carries no reason
    void entry.reason;
    // @ts-expect-error a sale carries no delta
    void entry.delta;
  } else if (entry.kind === "adjustment") {
    const delta: number = entry.delta;
    void delta;
    // @ts-expect-error an adjustment carries no amount
    void entry.amount;
  }
  amountOf(entry);
}

// @ts-expect-error the result may be null, so it is not an Entry yet
amountOf(decode("sale|1|eu"));

// @ts-expect-error an arbitrary object is not an Entry
amountOf({ kind: "sale" });

// @ts-expect-error "transfer" is not one of the entry kinds
amountOf({ kind: "transfer", amount: 1, region: "eu" });

// @ts-expect-error summarize takes lines, not a single string
summarize("sale|1|eu");

const report = summarize(["sale|1|eu"]);
const net: number = report.net;
const regions: string[] = report.regions;
const sales: number = report.counts.sale;
void net;
void regions;
void sales;
// @ts-expect-error the summary has no such field
void report.total;

export type { _Decode, _AmountArg, _AmountRet, _Summarize, _SummarizeArg };
