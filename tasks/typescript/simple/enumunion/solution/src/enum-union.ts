/** Bridging enum-shaped code and union-shaped code. */
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

export type LevelValue = `${Level}`;

export type LevelName = keyof typeof Level;

export type EnumValue<E> = E[keyof E];

export type EnumName<E> = keyof E & string;

export const LEVELS: readonly Level[] = [
  Level.Trace,
  Level.Debug,
  Level.Info,
  Level.Warn,
  Level.Error,
];

export function isLevel(value: unknown): value is Level {
  return typeof value === "string" && (LEVELS as readonly string[]).includes(value);
}

export function toLevel(value: string): Level | undefined {
  return isLevel(value) ? value : undefined;
}

export function levelName(level: Level): LevelName {
  const entries = Object.entries(Level) as [LevelName, Level][];
  for (const [name, member] of entries) {
    if (member === level) return name;
  }
  throw new RangeError(`unknown level: ${String(level)}`);
}

export function compareLevels(a: Level, b: Level): number {
  return LEVELS.indexOf(a) - LEVELS.indexOf(b);
}

const memberNames = (source: object): string[] =>
  Object.keys(source).filter((key) => !/^\d+$/.test(key));

export function enumValues<E extends object>(source: E): EnumValue<E>[] {
  const bag = source as Record<string, unknown>;
  return memberNames(source).map((name) => bag[name] as EnumValue<E>);
}

export function enumNames<E extends object>(source: E): EnumName<E>[] {
  return memberNames(source) as EnumName<E>[];
}
