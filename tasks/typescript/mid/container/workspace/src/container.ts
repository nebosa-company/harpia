/**
 * A dependency container.
 *
 * The declarations below are placeholders. A token has forgotten which
 * service it stands for, so `resolve` gives back `unknown` and every
 * call site has to cast — which is exactly the locator we are replacing.
 */
export type Token<T> = { readonly name: string };

export interface Container {
  register(token: Token<unknown>, factory: (c: Container) => unknown): Container;
  registerValue(token: Token<unknown>, value: unknown): Container;
  has(token: Token<unknown>): boolean;
  resolve(token: Token<unknown>): unknown;
  createScope(): Container;
}

export function token<T>(name: string): Token<T> {
  void name;
  throw new Error("token is not implemented");
}

export function tokenName(token: Token<unknown>): string {
  void token;
  throw new Error("tokenName is not implemented");
}

export function createContainer(): Container {
  throw new Error("createContainer is not implemented");
}
