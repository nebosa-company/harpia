import {
  asArray,
  asBoolean,
  asLiteral,
  asNumber,
  asObject,
  asOptional,
  asString,
  procedure,
} from "../src/contract";
import type { InputOf, OutputOf, Parser, Procedure } from "../src/contract";
import { createServer } from "../src/server";
import type { Handlers, Server } from "../src/server";
import { RpcError, createClient, inProcess } from "../src/client";
import type { Client, Transport } from "../src/client";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _String = Expect<Equals<typeof asString, Parser<string>>>;
type _Number = Expect<Equals<typeof asNumber, Parser<number>>>;
type _Boolean = Expect<Equals<typeof asBoolean, Parser<boolean>>>;
type _Literal = Expect<Equals<ReturnType<typeof asLiteral<"pong">>, Parser<"pong">>>;
type _Array = Expect<Equals<ReturnType<typeof asArray<number>>, Parser<number[]>>>;
type _Optional = Expect<
  Equals<ReturnType<typeof asOptional<string>>, Parser<string | undefined>>
>;

const user = asObject({ id: asNumber, name: asString });
type _Object = Expect<Equals<typeof user, Parser<{ id: number; name: string }>>>;

const api = {
  "user.get": procedure("user.get", asObject({ id: asNumber }), user),
  "user.list": procedure("user.list", asObject({ page: asNumber }), asArray(user)),
  ping: procedure("ping", asOptional(asString), asLiteral("pong")),
};

type Api = typeof api;

type _Proc = Expect<
  Equals<Api["user.get"], Procedure<{ id: number }, { id: number; name: string }>>
>;
type _InputOf = Expect<Equals<InputOf<Api["user.get"]>, { id: number }>>;
type _OutputOf = Expect<Equals<OutputOf<Api["user.get"]>, { id: number; name: string }>>;
type _ListOutput = Expect<
  Equals<OutputOf<Api["user.list"]>, { id: number; name: string }[]>
>;
type _PingInput = Expect<Equals<InputOf<Api["ping"]>, string | undefined>>;
type _PingOutput = Expect<Equals<OutputOf<Api["ping"]>, "pong">>;
type _NotAProcedure = Expect<Equals<InputOf<{ a: 1 }>, never>>;

type _Handlers = Expect<
  Equals<
    Handlers<Api>,
    {
      "user.get": (
        input: { id: number },
      ) => { id: number; name: string } | Promise<{ id: number; name: string }>;
      "user.list": (
        input: { page: number },
      ) => { id: number; name: string }[] | Promise<{ id: number; name: string }[]>;
      ping: (input: string | undefined) => "pong" | Promise<"pong">;
    }
  >
>;

const server: Server<Api> = createServer(api, {
  "user.get": ({ id }) => ({ id, name: "x" }),
  "user.list": async () => [],
  ping: (): "pong" => "pong",
});

type _Procedures = Expect<
  Equals<typeof server.procedures, readonly ("user.get" | "user.list" | "ping")[]>
>;

// @ts-expect-error every procedure needs a handler: "ping" is missing
createServer(api, { "user.get": ({ id }) => ({ id, name: "x" }), "user.list": () => [] });

createServer(api, {
  // @ts-expect-error the handler must return what the contract promises
  "user.get": () => ({ id: 1 }),
  "user.list": () => [],
  ping: (): "pong" => "pong",
});

createServer(api, {
  "user.get": ({ id }) => ({ id, name: "x" }),
  "user.list": () => [],
  // @ts-expect-error ping answers with the literal "pong"
  ping: () => "pang",
});

createServer(api, {
  // @ts-expect-error the handler input follows the contract
  "user.get": (input: { slug: string }) => ({ id: 1, name: input.slug }),
  "user.list": () => [],
  ping: (): "pong" => "pong",
});

const transport: Transport = inProcess(server);
const client: Client<Api> = createClient(api, transport);

const got = client["user.get"]({ id: 1 });
type _Get = Expect<Equals<typeof got, Promise<{ id: number; name: string }>>>;
const listed = client["user.list"]({ page: 1 });
type _List = Expect<Equals<typeof listed, Promise<{ id: number; name: string }[]>>>;
const ponged = client.ping(undefined);
type _Ping = Expect<Equals<typeof ponged, Promise<"pong">>>;

// @ts-expect-error the client takes the contract's input shape
client["user.get"]({ slug: "ada" });

// @ts-expect-error the id is a number
client["user.get"]({ id: "1" });

// @ts-expect-error the contract has no such procedure
client["user.delete"]({ id: 1 });

declare const err: RpcError;
const code: "unknown_procedure" | "bad_input" | "handler_error" | "bad_output" = err.code;
const asError: Error = err;
void code;
void asError;
// @ts-expect-error the code is not a free-form string
const wrongCode: "nope" = err.code;
void wrongCode;

export type {
  _String,
  _Number,
  _Boolean,
  _Literal,
  _Array,
  _Optional,
  _Object,
  _Proc,
  _InputOf,
  _OutputOf,
  _ListOutput,
  _PingInput,
  _PingOutput,
  _NotAProcedure,
  _Handlers,
  _Procedures,
  _Get,
  _List,
  _Ping,
};
