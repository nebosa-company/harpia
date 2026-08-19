// Ambient declarations for the node builtins the visible tests use.
// The project installs no packages, so no @types/node is available.
declare module "node:test" {
  export function test(name: string, fn: () => void | Promise<void>): void;
  export function describe(name: string, fn: () => void): void;
  export function it(name: string, fn: () => void | Promise<void>): void;
}
declare module "node:assert/strict" {
  interface Assert {
    (value: unknown, message?: string): void;
    ok(value: unknown, message?: string): void;
    equal(actual: unknown, expected: unknown, message?: string): void;
    notEqual(actual: unknown, expected: unknown, message?: string): void;
    strictEqual(actual: unknown, expected: unknown, message?: string): void;
    deepEqual(actual: unknown, expected: unknown, message?: string): void;
    notDeepEqual(actual: unknown, expected: unknown, message?: string): void;
    throws(fn: () => unknown, expected?: unknown, message?: string): void;
    doesNotThrow(fn: () => unknown, message?: string): void;
    match(actual: string, expected: RegExp, message?: string): void;
    fail(message?: string): never;
  }
  const assert: Assert;
  export default assert;
}
