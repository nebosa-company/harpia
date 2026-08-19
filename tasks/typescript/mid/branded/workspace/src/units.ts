/**
 * Physical units.
 *
 * The aliases below are placeholders: every unit is still a bare
 * `number`, so metres, seconds and speeds are interchangeable and the
 * compiler has nothing to say about it.
 */
export type Brand<T, Name extends string> = T;

export type Metres = Brand<number, "Metres">;

export type Seconds = Brand<number, "Seconds">;

export type MetresPerSecond = Brand<number, "MetresPerSecond">;

export type AnyUnit = Metres | Seconds | MetresPerSecond;

function unimplemented(name: string): never {
  throw new Error(`${name} is not implemented`);
}

export function metres(value: number): Metres {
  void value;
  return unimplemented("metres");
}

export function seconds(value: number): Seconds {
  void value;
  return unimplemented("seconds");
}

export function metresPerSecond(value: number): MetresPerSecond {
  void value;
  return unimplemented("metresPerSecond");
}

export function addMetres(a: Metres, b: Metres): Metres {
  void a;
  void b;
  return unimplemented("addMetres");
}

export function subtractMetres(a: Metres, b: Metres): Metres {
  void a;
  void b;
  return unimplemented("subtractMetres");
}

export function scaleMetres(distance: Metres, factor: number): Metres {
  void distance;
  void factor;
  return unimplemented("scaleMetres");
}

export function addSeconds(a: Seconds, b: Seconds): Seconds {
  void a;
  void b;
  return unimplemented("addSeconds");
}

export function speed(distance: Metres, time: Seconds): MetresPerSecond {
  void distance;
  void time;
  return unimplemented("speed");
}

export function travelled(rate: MetresPerSecond, time: Seconds): Metres {
  void rate;
  void time;
  return unimplemented("travelled");
}

export function toNumber(value: AnyUnit): number {
  void value;
  return unimplemented("toNumber");
}

export function compare(a: Metres, b: Metres): number {
  void a;
  void b;
  return unimplemented("compare");
}
