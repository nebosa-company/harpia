/**
 * The server side.
 *
 * The declarations below are placeholders: the handler table is not
 * tied to the contract, so a missing handler or a mistyped payload
 * sails straight through the build.
 */
import type { Contract } from "./contract";

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

export type Handlers<C extends Contract> = Record<
  string,
  (input: unknown) => unknown | Promise<unknown>
>;

export interface Server<C extends Contract> {
  readonly procedures: readonly string[];
  handle(request: RpcRequest): Promise<RpcResponse>;
}

export function createServer<C extends Contract>(
  contract: C,
  handlers: Handlers<C>,
): Server<C> {
  void contract;
  void handlers;
  throw new Error("createServer is not implemented");
}
