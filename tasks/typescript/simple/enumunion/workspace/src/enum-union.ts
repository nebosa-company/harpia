/**
 * Bridging enum-shaped code and union-shaped code.
 *
 * The enums are settled. Everything below them is a placeholder: the
 * types widen to `string`/`number`, so nothing that crosses this module
 * keeps its literal shape.
 */
export enum Level {
  Trace = "trace",
  Debug = "debug",
  Info = "info",
  Warn = "warn",
  Error = "error",
}

export enum Priority {
  Low = 1,
  Normal = 5,
  High = 10,
}

export type LevelValue = string;

export type LevelName = string;

export type EnumValue<E> = string | number;

export type EnumName<E> = string;

export const LEVELS: readonly Level[] = [];

export function isLevel(value: unknown): boolean {
  void value;
  throw new Error("isLevel is not implemented");
}

export function toLevel(value: string): Level | undefined {
  void value;
  throw new Error("toLevel is not implemented");
}

export function levelName(level: Level): string {
  void level;
  throw new Error("levelName is not implemented");
}

export function compareLevels(a: Level, b: Level): number {
  void a;
  void b;
  throw new Error("compareLevels is not implemented");
}

export function enumValues<E extends object>(source: E): (string | number)[] {
  void source;
  throw new Error("enumValues is not implemented");
}

export function enumNames<E extends object>(source: E): string[] {
  void source;
  throw new Error("enumNames is not implemented");
}
