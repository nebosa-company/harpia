import {
  addMetres,
  addSeconds,
  compare,
  metres,
  metresPerSecond,
  scaleMetres,
  seconds,
  speed,
  subtractMetres,
  toNumber,
  travelled,
} from "../src/units";
import type { Metres, MetresPerSecond, Seconds } from "../src/units";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _Metres = Expect<Equals<ReturnType<typeof metres>, Metres>>;
type _Seconds = Expect<Equals<ReturnType<typeof seconds>, Seconds>>;
type _Speed = Expect<Equals<ReturnType<typeof speed>, MetresPerSecond>>;
type _Add = Expect<Equals<ReturnType<typeof addMetres>, Metres>>;
type _Sub = Expect<Equals<ReturnType<typeof subtractMetres>, Metres>>;
type _Scale = Expect<Equals<ReturnType<typeof scaleMetres>, Metres>>;
type _Travelled = Expect<Equals<ReturnType<typeof travelled>, Metres>>;
type _ToNumber = Expect<Equals<ReturnType<typeof toNumber>, number>>;
type _Compare = Expect<Equals<ReturnType<typeof compare>, number>>;

const d: Metres = metres(3);
const t: Seconds = seconds(2);
const v: MetresPerSecond = metresPerSecond(1.5);

// a branded unit is still usable as a number
const plain: number = d;
void plain;

addMetres(d, metres(1));
addSeconds(t, seconds(1));
speed(d, t);
travelled(v, t);
scaleMetres(d, 2);
compare(d, metres(1));

// @ts-expect-error a bare number is not a distance
const notMetres: Metres = 3;
void notMetres;

// @ts-expect-error a duration is not a distance
const wrongUnit: Metres = t;
void wrongUnit;

// @ts-expect-error a distance is not a duration
const alsoWrong: Seconds = d;
void alsoWrong;

// @ts-expect-error a speed is not a distance
const stillWrong: Metres = v;
void stillWrong;

// @ts-expect-error metres and seconds do not add
addMetres(d, t);

// @ts-expect-error a plain number is not a distance
addMetres(d, 4);

// @ts-expect-error seconds do not add to metres
addSeconds(t, d);

// @ts-expect-error speed takes a distance then a duration, in that order
speed(t, d);

// @ts-expect-error a distance is not a rate
travelled(d, t);

// @ts-expect-error scaleMetres needs a distance to scale
scaleMetres(2, 3);

// @ts-expect-error compare works on distances only
compare(d, t);

// @ts-expect-error an unbranded number cannot be unwrapped
toNumber(3);

toNumber(d);
toNumber(t);
toNumber(v);

export type {
  _Metres,
  _Seconds,
  _Speed,
  _Add,
  _Sub,
  _Scale,
  _Travelled,
  _ToNumber,
  _Compare,
};
