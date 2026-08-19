/** The server side, driven by the shared contract. */
import type { Contract, InputOf, OutputOf, Procedure } from "./contract";

export type RpcErrorCode =
  | "unknown_procedure"
  | "bad_input"
  | "handler_error"
  | "bad_output";

export interface RpcRequest {
  procedure: string;
  input: unknown;
}

export type RpcResponse =
  | { ok: true; output: unknown }
  | { ok: false; error: { code: RpcErrorCode; message: string } };

export type Handlers<C extends Contract> = {
  [K in keyof C]: (input: InputOf<C[K]>) => OutputOf<C[K]> | Promise<OutputOf<C[K]>>;
};

export interface Server<C extends Contract> {
  readonly procedures: readonly (keyof C & string)[];
  handle(request: RpcRequest): Promise<RpcResponse>;
}

function messageOf(cause: unknown): string {
  return cause instanceof Error ? cause.message : String(cause);
}

const failure = (code: RpcErrorCode, message: string): RpcResponse => ({
  ok: false,
  error: { code, message },
});

export function createServer<C extends Contract>(
  contract: C,
  handlers: Handlers<C>,
): Server<C> {
  const procedures = Object.keys(contract) as (keyof C & string)[];
  const table = contract as Record<string, Procedure<unknown, unknown> | undefined>;
  const impl = handlers as unknown as Record<
    string,
    ((input: unknown) => unknown) | undefined
  >;

  return {
    procedures,

    async handle(request: RpcRequest): Promise<RpcResponse> {
      const proc = table[request.procedure];
      const handler = impl[request.procedure];
      if (proc === undefined || handler === undefined) {
        return failure(
          "unknown_procedure",
          `unknown procedure: "${request.procedure}"`,
        );
      }

      let input: unknown;
      try {
        input = proc.input(request.input);
      } catch (cause) {
        return failure("bad_input", messageOf(cause));
      }

      let produced: unknown;
      try {
        produced = await handler(input);
      } catch (cause) {
        return failure("handler_error", messageOf(cause));
      }

      try {
        return { ok: true, output: proc.output(produced) };
      } catch (cause) {
        return failure("bad_output", messageOf(cause));
      }
    },
  };
}
