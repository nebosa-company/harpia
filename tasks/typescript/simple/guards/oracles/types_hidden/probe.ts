import {
  MESSAGE_KINDS,
  assertMessage,
  assertMessageOfKind,
  describe,
  isMessage,
  isMessageOfKind,
} from "../src/messages";
import type {
  ChatMessage,
  ErrorMessage,
  JoinMessage,
  Message,
  MessageKind,
  MessageOfKind,
  PingMessage,
} from "../src/messages";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _Kinds = Expect<Equals<MessageKind, "ping" | "chat" | "join" | "error">>;
type _OfChat = Expect<Equals<MessageOfKind<"chat">, ChatMessage>>;
type _OfPing = Expect<Equals<MessageOfKind<"ping">, PingMessage>>;
type _OfJoin = Expect<Equals<MessageOfKind<"join">, JoinMessage>>;
type _OfError = Expect<Equals<MessageOfKind<"error">, ErrorMessage>>;
type _Const = Expect<Equals<typeof MESSAGE_KINDS, readonly MessageKind[]>>;
type _Describe = Expect<Equals<Parameters<typeof describe>[0], Message>>;

declare const wire: unknown;

if (isMessage(wire)) {
  const kind: MessageKind = wire.kind;
  void kind;
  if (wire.kind === "chat") {
    const from: string = wire.from;
    const body: string = wire.body;
    void from;
    void body;
    // @ts-expect-error a chat message carries no nonce
    void wire.nonce;
  }
  describe(wire);
} else {
  // @ts-expect-error outside the guard the value is still unknown
  describe(wire);
}

if (isMessageOfKind(wire, "join")) {
  const room: string = wire.room;
  const members: string[] = wire.members;
  void room;
  void members;
  // @ts-expect-error a join message carries no code
  void wire.code;
}

// @ts-expect-error "leave" is not a message kind
isMessageOfKind(wire, "leave");

declare const other: unknown;
assertMessage(other);
const afterAssert: Message = other;
void afterAssert;
describe(other);

declare const third: unknown;
assertMessageOfKind(third, "error");
const err: ErrorMessage = third;
const code: number = third.code;
void err;
void code;
// @ts-expect-error an error message carries no body
void third.body;

// @ts-expect-error "leave" is not a message kind
assertMessageOfKind(other, "leave");

// @ts-expect-error describe needs a message, not an arbitrary object
describe({ kind: "ping" });

// @ts-expect-error describe is closed over the union
describe({ kind: "leave", room: "x" });

export type { _Kinds, _OfChat, _OfPing, _OfJoin, _OfError, _Const, _Describe };
