/** Physical units, distinguished by a phantom brand. */
declare const BRAND: unique symbol;

export type Brand<T, Name extends string> = T & { readonly [BRAND]: Name };

export type Metres = Brand<number, "Metres">;

export type Seconds = Brand<number, "Seconds">;

export type MetresPerSecond = Brand<number, "MetresPerSecond">;

export type AnyUnit = Metres | Seconds | MetresPerSecond;

function finite(value: number, unit: string): void {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new RangeError(`${unit} must be finite`);
  }
}

export function metres(value: number): Metres {
  finite(value, "metres");
  return value as Metres;
}

export function seconds(value: number): Seconds {
  finite(value, "seconds");
  if (value < 0) {
    throw new RangeError("seconds must not be negative");
  }
  return value as Seconds;
}

export function metresPerSecond(value: number): MetresPerSecond {
  finite(value, "metresPerSecond");
  return value as MetresPerSecond;
}

export function addMetres(a: Metres, b: Metres): Metres {
  return metres((a as number) + (b as number));
}

export function subtractMetres(a: Metres, b: Metres): Metres {
  return metres((a as number) - (b as number));
}

export function scaleMetres(distance: Metres, factor: number): Metres {
  finite(factor, "metres");
  return metres((distance as number) * factor);
}

export function addSeconds(a: Seconds, b: Seconds): Seconds {
  return seconds((a as number) + (b as number));
}

export function speed(distance: Metres, time: Seconds): MetresPerSecond {
  if ((time as number) === 0) {
    throw new RangeError("time must be greater than zero");
  }
  return metresPerSecond((distance as number) / (time as number));
}

export function travelled(rate: MetresPerSecond, time: Seconds): Metres {
  return metres((rate as number) * (time as number));
}

export function toNumber(value: AnyUnit): number {
  return value as number;
}

export function compare(a: Metres, b: Metres): number {
  return (a as number) - (b as number);
}
