/** The client side, derived from the same contract as the server. */
import type { Contract, InputOf, OutputOf, Procedure } from "./contract";
import type { RpcErrorCode, RpcRequest, RpcResponse, Server } from "./server";

export type Transport = (request: RpcRequest) => Promise<RpcResponse>;

export type Client<C extends Contract> = {
  [K in keyof C]: (input: InputOf<C[K]>) => Promise<OutputOf<C[K]>>;
};

export class RpcError extends Error {
  readonly code: RpcErrorCode;

  constructor(code: RpcErrorCode, message: string) {
    super(message);
    this.name = "RpcError";
    this.code = code;
  }
}

export function createClient<C extends Contract>(
  contract: C,
  transport: Transport,
): Client<C> {
  const table = contract as Record<string, Procedure<unknown, unknown>>;
  const client: Record<string, (input: unknown) => Promise<unknown>> = {};

  for (const key of Object.keys(table)) {
    const proc = table[key] as Procedure<unknown, unknown>;
    client[key] = async (input: unknown): Promise<unknown> => {
      const response = await transport({ procedure: key, input });
      if (!response.ok) {
        throw new RpcError(response.error.code, response.error.message);
      }
      try {
        return proc.output(response.output);
      } catch (cause) {
        throw new RpcError(
          "bad_output",
          cause instanceof Error ? cause.message : String(cause),
        );
      }
    };
  }

  return client as Client<C>;
}

export function inProcess<C extends Contract>(server: Server<C>): Transport {
  return (request: RpcRequest): Promise<RpcResponse> => server.handle(request);
}
