import { createMachine, reachableFrom } from "../src/machine";
import type { EventOf, Machine, NextState, StateOf } from "../src/machine";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

const checkout = {
  idle: { start: "loading" },
  loading: { resolve: "ready", reject: "failed" },
  ready: { reset: "idle" },
  failed: { retry: "loading", reset: "idle" },
} as const;

type Checkout = typeof checkout;

type _States = Expect<Equals<StateOf<Checkout>, "idle" | "loading" | "ready" | "failed">>;
type _IdleEvents = Expect<Equals<EventOf<Checkout, "idle">, "start">>;
type _LoadingEvents = Expect<Equals<EventOf<Checkout, "loading">, "resolve" | "reject">>;
type _FailedEvents = Expect<Equals<EventOf<Checkout, "failed">, "retry" | "reset">>;
type _Next = Expect<Equals<NextState<Checkout, "loading", "resolve">, "ready">>;
type _Next2 = Expect<Equals<NextState<Checkout, "failed", "reset">, "idle">>;

// the literal types are inferred from a plain object literal, with no `as const`
const machine = createMachine(
  {
    idle: { start: "loading" },
    loading: { resolve: "ready", reject: "failed" },
    ready: { reset: "idle" },
    failed: { retry: "loading", reset: "idle" },
  },
  "idle",
);

type _State = Expect<Equals<typeof machine.state, "idle">>;

const loading = machine.send("start");
type _Loading = Expect<Equals<typeof loading.state, "loading">>;

const ready = loading.send("resolve");
type _Ready = Expect<Equals<typeof ready.state, "ready">>;

const back = ready.send("reset");
type _Back = Expect<Equals<typeof back.state, "idle">>;

// @ts-expect-error "resolve" is not an event of the idle state
machine.send("resolve");

// @ts-expect-error "start" is not an event of the loading state
loading.send("start");

// @ts-expect-error "retry" belongs to the failed state
loading.send("retry");

// @ts-expect-error nothing leaves ready except reset
ready.send("resolve");

// can() is deliberately open, so a wire string is fine
machine.can("anything at all");

declare const typed: Machine<Checkout, "failed">;
type _TypedEvents = Expect<
  Equals<Parameters<typeof typed.send>[0], "retry" | "reset">
>;
type _History = Expect<
  Equals<typeof typed.history, readonly ("idle" | "loading" | "ready" | "failed")[]>
>;

const reached = reachableFrom(checkout, "idle");
type _Reached = Expect<Equals<typeof reached, StateOf<Checkout>[]>>;

// @ts-expect-error "nowhere" is not a state of this table
reachableFrom(checkout, "nowhere");

export type {
  _States,
  _IdleEvents,
  _LoadingEvents,
  _FailedEvents,
  _Next,
  _Next2,
  _State,
  _Loading,
  _Ready,
  _Back,
  _TypedEvents,
  _History,
  _Reached,
};
