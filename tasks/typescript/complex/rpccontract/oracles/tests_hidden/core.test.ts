import { test } from "node:test";
import assert from "node:assert/strict";
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
import { createServer } from "../src/server";
import { RpcError, createClient, inProcess } from "../src/client";

const user = asObject({ id: asNumber, name: asString });

const api = {
  "user.get": procedure("user.get", asObject({ id: asNumber }), user),
  "user.list": procedure("user.list", asObject({ page: asNumber }), asArray(user)),
  "user.create": procedure(
    "user.create",
    asObject({ name: asString, active: asBoolean }),
    asObject({ id: asNumber }),
  ),
  ping: procedure("ping", asOptional(asString), asLiteral("pong")),
};

const people = [
  { id: 1, name: "ada" },
  { id: 2, name: "grace" },
];

const buildServer = () =>
  createServer(api, {
    "user.get": ({ id }) => {
      const found = people.find((p) => p.id === id);
      if (found === undefined) throw new RangeError(`no user ${id}`);
      return found;
    },
    "user.list": async ({ page }) => (page === 1 ? people : []),
    "user.create": ({ name, active }) => ({ id: active ? name.length : 0 }),
    ping: (): "pong" => "pong",
  });

test("parsers accept and reject", () => {
  assert.equal(asString("a"), "a");
  assert.throws(() => asString(1), (e: unknown) => e instanceof TypeError && e.message === "expected string");
  assert.equal(asNumber(1.5), 1.5);
  assert.throws(() => asNumber("1"), (e: unknown) => e instanceof TypeError && e.message === "expected number");
  assert.throws(() => asNumber(Number.NaN), TypeError);
  assert.throws(() => asNumber(Number.POSITIVE_INFINITY), TypeError);
  assert.equal(asBoolean(false), false);
  assert.throws(() => asBoolean(0), (e: unknown) => e instanceof TypeError && e.message === "expected boolean");
  assert.equal(asLiteral("pong")("pong"), "pong");
  assert.throws(
    () => asLiteral("pong")("ping"),
    (e: unknown) => e instanceof TypeError && e.message === 'expected literal "pong"',
  );
  assert.equal(asOptional(asString)(undefined), undefined);
  assert.equal(asOptional(asString)("a"), "a");
  assert.throws(() => asOptional(asString)(1), TypeError);
});

test("array parsing names the failing index", () => {
  assert.deepEqual(asArray(asNumber)([1, 2]), [1, 2]);
  assert.deepEqual(asArray(asNumber)([]), []);
  assert.throws(
    () => asArray(asNumber)("nope"),
    (e: unknown) => e instanceof TypeError && e.message === "expected array",
  );
  assert.throws(
    () => asArray(asNumber)([1, "x"]),
    (e: unknown) => e instanceof TypeError && e.message === "[1] expected number",
  );
});

test("object parsing names the failing field and drops extras", () => {
  assert.deepEqual(user({ id: 1, name: "ada", extra: true }), { id: 1, name: "ada" });
  for (const bad of [null, [], "x", 3]) {
    assert.throws(
      () => user(bad),
      (e: unknown) => e instanceof TypeError && e.message === "expected object",
    );
  }
  assert.throws(
    () => user({ id: "1", name: "ada" }),
    (e: unknown) => e instanceof TypeError && e.message === "id expected number",
  );
  assert.throws(
    () => user({ id: 1 }),
    (e: unknown) => e instanceof TypeError && e.message === "name expected string",
  );
});

test("an optional field may be missing and is then omitted", () => {
  const parse = asObject({ id: asNumber, nickname: asOptional(asString) });
  assert.deepEqual(parse({ id: 1 }), { id: 1 });
  assert.deepEqual(parse({ id: 1, nickname: "z" }), { id: 1, nickname: "z" });
});

test("nested parser messages compose", () => {
  const parse = asObject({ users: asArray(user) });
  assert.throws(
    () => parse({ users: [{ id: 1, name: "ada" }, { id: "2", name: "x" }] }),
    (e: unknown) => e instanceof TypeError && e.message === "users [1] id expected number",
  );
});

test("procedure keeps its name and parsers", () => {
  assert.equal(api["user.get"].name, "user.get");
  assert.deepEqual(api["user.get"].input({ id: 3 }), { id: 3 });
});

test("the server lists its procedures in contract order", () => {
  assert.deepEqual([...buildServer().procedures], [
    "user.get",
    "user.list",
    "user.create",
    "ping",
  ]);
});

test("a good call round-trips through the server", async () => {
  const server = buildServer();
  assert.deepEqual(await server.handle({ procedure: "user.get", input: { id: 1 } }), {
    ok: true,
    output: { id: 1, name: "ada" },
  });
  assert.deepEqual(await server.handle({ procedure: "ping", input: undefined }), {
    ok: true,
    output: "pong",
  });
});

test("the server answers an unknown procedure", async () => {
  const server = buildServer();
  assert.deepEqual(await server.handle({ procedure: "user.delete", input: {} }), {
    ok: false,
    error: {
      code: "unknown_procedure",
      message: 'unknown procedure: "user.delete"',
    },
  });
});

test("the server answers bad input", async () => {
  const server = buildServer();
  assert.deepEqual(await server.handle({ procedure: "user.get", input: { id: "1" } }), {
    ok: false,
    error: { code: "bad_input", message: "id expected number" },
  });
  assert.deepEqual(await server.handle({ procedure: "user.get", input: null }), {
    ok: false,
    error: { code: "bad_input", message: "expected object" },
  });
});

test("the server answers a throwing handler", async () => {
  const server = buildServer();
  assert.deepEqual(await server.handle({ procedure: "user.get", input: { id: 9 } }), {
    ok: false,
    error: { code: "handler_error", message: "no user 9" },
  });
});

test("the server answers a rejected handler and a non-Error throw", async () => {
  const contract = {
    boom: procedure("boom", asOptional(asString), asString),
    reject: procedure("reject", asOptional(asString), asString),
  };
  const server = createServer(contract, {
    boom: () => {
      throw "plain string";
    },
    reject: async () => {
      throw new Error("later");
    },
  });
  assert.deepEqual(await server.handle({ procedure: "boom", input: undefined }), {
    ok: false,
    error: { code: "handler_error", message: "plain string" },
  });
  assert.deepEqual(await server.handle({ procedure: "reject", input: undefined }), {
    ok: false,
    error: { code: "handler_error", message: "later" },
  });
});

test("the server answers a handler whose output does not fit", async () => {
  const contract = { bad: procedure("bad", asOptional(asString), asNumber) };
  const server = createServer(contract, {
    bad: () => "not a number" as unknown as number,
  });
  assert.deepEqual(await server.handle({ procedure: "bad", input: undefined }), {
    ok: false,
    error: { code: "bad_output", message: "expected number" },
  });
});

test("the response carries the parsed output, not the raw one", async () => {
  const contract = { get: procedure("get", asOptional(asString), user) };
  const server = createServer(contract, {
    get: () => ({ id: 1, name: "ada", secret: "x" }) as unknown as { id: number; name: string },
  });
  const response = await server.handle({ procedure: "get", input: undefined });
  assert.deepEqual(response, { ok: true, output: { id: 1, name: "ada" } });
});

test("the client speaks the contract", async () => {
  const client = createClient(api, inProcess(buildServer()));
  assert.deepEqual(await client["user.get"]({ id: 2 }), { id: 2, name: "grace" });
  assert.deepEqual(await client["user.list"]({ page: 1 }), people);
  assert.deepEqual(await client["user.list"]({ page: 2 }), []);
  assert.deepEqual(await client["user.create"]({ name: "kay", active: true }), { id: 3 });
  assert.equal(await client.ping(undefined), "pong");
});

test("the client turns a failure into an RpcError", async () => {
  const client = createClient(api, inProcess(buildServer()));
  await assert.rejects(
    () => client["user.get"]({ id: 99 }),
    (err: unknown) =>
      err instanceof RpcError &&
      err instanceof Error &&
      err.name === "RpcError" &&
      err.code === "handler_error" &&
      err.message === "no user 99",
  );
});

test("the client reports an unknown procedure from the transport", async () => {
  const transport = async (): Promise<{
    ok: false;
    error: { code: "unknown_procedure"; message: string };
  }> => ({
    ok: false,
    error: { code: "unknown_procedure", message: 'unknown procedure: "ping"' },
  });
  const client = createClient(api, transport);
  await assert.rejects(
    () => client.ping(undefined),
    (err: unknown) => err instanceof RpcError && err.code === "unknown_procedure",
  );
});

test("the client validates the output it was given", async () => {
  const transport = async (): Promise<{ ok: true; output: unknown }> => ({
    ok: true,
    output: { id: "1", name: "ada" },
  });
  const client = createClient(api, transport);
  await assert.rejects(
    () => client["user.get"]({ id: 1 }),
    (err: unknown) =>
      err instanceof RpcError &&
      err.code === "bad_output" &&
      err.message === "id expected number",
  );
});

test("the client sends the contract key as the procedure name", async () => {
  const seen: string[] = [];
  const server = buildServer();
  const client = createClient(api, async (request) => {
    seen.push(request.procedure);
    return server.handle(request);
  });
  await client.ping(undefined);
  await client["user.get"]({ id: 1 });
  assert.deepEqual(seen, ["ping", "user.get"]);
});
