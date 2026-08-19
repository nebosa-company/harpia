import { createEmitter } from "../src/emitter";
import type { Emitter } from "../src/emitter";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type Events = {
  saved: { id: string; size: number };
  closed: void;
  tick: number;
};

const e: Emitter<Events> = createEmitter<Events>();

// the listener payload is narrowed per key, with no annotation
e.on("saved", (p) => {
  const id: string = p.id;
  const size: number = p.size;
  void id;
  void size;
});
e.on("tick", (p) => {
  const n: number = p;
  void n;
});

// @ts-expect-error "opened" is not an event of this map
e.on("opened", () => {});

// @ts-expect-error a saved payload is not a number
e.on("saved", (p: number) => void p);

// @ts-expect-error emit must carry the payload of the key it was given
e.emit("saved", 42);

// @ts-expect-error a saved payload with a missing field is still wrong
e.emit("saved", { id: "a" });

// @ts-expect-error tick carries a number, not a string
e.emit("tick", "1");

// @ts-expect-error unknown key
e.emit("nope", 1);

// @ts-expect-error unknown key
e.listenerCount("nope");

// @ts-expect-error unknown key
e.off("nope", () => {});

e.emit("saved", { id: "a", size: 1 });
e.emit("tick", 1);
e.emit("closed", undefined);

const unsubscribe = e.on("tick", () => {});
type _Unsub = Expect<Equals<typeof unsubscribe, () => void>>;
type _Once = Expect<Equals<ReturnType<Emitter<Events>["once"]>, () => void>>;
type _Emit = Expect<Equals<ReturnType<Emitter<Events>["emit"]>, number>>;
type _Count = Expect<Equals<ReturnType<Emitter<Events>["listenerCount"]>, number>>;
type _Off = Expect<Equals<ReturnType<Emitter<Events>["off"]>, void>>;

// a contextually typed listener keeps its exact payload type
declare function onSaved(
  em: Emitter<Events>,
  fn: (p: { id: string; size: number }) => void,
): void;
onSaved(e, (p) => void p.id);

export type { _Unsub, _Once, _Emit, _Count, _Off };
