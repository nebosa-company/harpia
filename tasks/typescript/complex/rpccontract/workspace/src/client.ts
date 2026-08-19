/**
 * The client side.
 *
 * The declarations below are placeholders: a client is just "an object
 * of functions taking unknown", so nothing the contract says reaches
 * the call site.
 */
import type { Contract } from "./contract";
import type { RpcErrorCode, RpcRequest, RpcResponse, Server } from "./server";

export type Transport = (request: RpcRequest) => Promise<RpcResponse>;

export type Client<C extends Contract> = Record<
  string,
  (input: unknown) => Promise<unknown>
>;

export class RpcError extends Error {
  readonly code: RpcErrorCode;

  constructor(code: RpcErrorCode, message: string) {
    super(message);
    this.code = code;
  }
}

export function createClient<C extends Contract>(
  contract: C,
  transport: Transport,
): Client<C> {
  void contract;
  void transport;
  throw new Error("createClient is not implemented");
}

export function inProcess<C extends Contract>(server: Server<C>): Transport {
  void server;
  throw new Error("inProcess is not implemented");
}
