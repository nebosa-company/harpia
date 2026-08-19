import { createContainer, token, tokenName } from "../src/container";
import type { Container, Token } from "../src/container";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

interface Logger {
  lines: string[];
}

const PORT: Token<number> = token<number>("port");
const NAME: Token<string> = token<string>("name");
const LOGGER: Token<Logger> = token<Logger>("logger");

const c: Container = createContainer();

const port = c.resolve(PORT);
type _Port = Expect<Equals<typeof port, number>>;
const logger = c.resolve(LOGGER);
type _Logger = Expect<Equals<typeof logger, Logger>>;
type _TokenName = Expect<Equals<ReturnType<typeof tokenName>, string>>;
type _Has = Expect<Equals<ReturnType<Container["has"]>, boolean>>;
type _Scope = Expect<Equals<ReturnType<Container["createScope"]>, Container>>;

const lines: string[] = c.resolve(LOGGER).lines;
void lines;
void port;

// @ts-expect-error the port token stands for a number
const wrongUse: string = c.resolve(PORT);
void wrongUse;

// @ts-expect-error the value must match the token's service type
c.registerValue(PORT, "8080");

// @ts-expect-error the factory must produce the token's service type
c.register(PORT, () => "8080");

// @ts-expect-error a Token<string> is not a Token<number>
const swapped: Token<number> = NAME;
void swapped;

// @ts-expect-error a plain object is not a token
c.resolve({ name: "port" });

// @ts-expect-error the factory takes the container, not a service
c.register(LOGGER, (inner: Logger) => inner);

// a factory may resolve its own dependencies, still fully typed
c.register(LOGGER, (inner) => {
  const p: number = inner.resolve(PORT);
  return { lines: [String(p)] };
});

// any token may be inspected by name
tokenName(PORT);
tokenName(NAME);
tokenName(LOGGER);

// register chains because it returns a Container
const chained: Container = c.registerValue(PORT, 1).registerValue(NAME, "x");
void chained;

export type { _Port, _Logger, _TokenName, _Has, _Scope };
