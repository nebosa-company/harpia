import {
  LEVELS,
  Level,
  Priority,
  compareLevels,
  enumNames,
  enumValues,
  isLevel,
  levelName,
  toLevel,
} from "../src/enum-union";
import type { EnumName, EnumValue, LevelName, LevelValue } from "../src/enum-union";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _LevelValue = Expect<
  Equals<LevelValue, "trace" | "debug" | "info" | "warn" | "error">
>;
type _LevelName = Expect<
  Equals<LevelName, "Trace" | "Debug" | "Info" | "Warn" | "Error">
>;
type _EnumNamesOfLevel = Expect<Equals<EnumName<typeof Level>, LevelName>>;
type _EnumNamesOfPriority = Expect<
  Equals<EnumName<typeof Priority>, "Low" | "Normal" | "High">
>;
type _EnumValuesOfLevel = Expect<
  Equals<
    EnumValue<typeof Level>,
    Level.Trace | Level.Debug | Level.Info | Level.Warn | Level.Error
  >
>;
type _EnumValuesOfPriority = Expect<
  Equals<EnumValue<typeof Priority>, Priority.Low | Priority.Normal | Priority.High>
>;

type _Levels = Expect<Equals<typeof LEVELS, readonly Level[]>>;
type _ToLevel = Expect<Equals<ReturnType<typeof toLevel>, Level | undefined>>;
type _LevelNameRet = Expect<Equals<ReturnType<typeof levelName>, LevelName>>;
type _Compare = Expect<Equals<ReturnType<typeof compareLevels>, number>>;

const names = enumNames(Level);
type _NamesArray = Expect<Equals<typeof names, LevelName[]>>;
const priorityNames = enumNames(Priority);
type _PriorityNames = Expect<Equals<typeof priorityNames, ("Low" | "Normal" | "High")[]>>;
const priorityValues = enumValues(Priority);
type _PriorityValues = Expect<
  Equals<typeof priorityValues, (Priority.Low | Priority.Normal | Priority.High)[]>
>;
const asPriorities: Priority[] = priorityValues;
const asLevels: Level[] = enumValues(Level);
void asPriorities;
void asLevels;
// @ts-expect-error a string enum's values are not numbers
const asNumbers: number[] = enumValues(Level);
void asNumbers;

declare const raw: unknown;
if (isLevel(raw)) {
  const level: Level = raw;
  void level;
  levelName(raw);
} else {
  // @ts-expect-error outside the guard the value is still unknown
  levelName(raw);
}

// @ts-expect-error a bare string is not a Level
levelName("info");

// @ts-expect-error a Priority is not a Level
levelName(Priority.Low);

// @ts-expect-error compareLevels takes members, not wire strings
compareLevels("trace", "error");

const name: LevelName = levelName(Level.Info);
void name;
// @ts-expect-error "info" is the value, not the name
const wrong: LevelName = "info";
void wrong;

const value: LevelValue = Level.Info;
void value;
// @ts-expect-error "Info" is the name, not the value
const wrongValue: LevelValue = "Info";
void wrongValue;

export type {
  _LevelValue,
  _LevelName,
  _EnumNamesOfLevel,
  _EnumNamesOfPriority,
  _EnumValuesOfLevel,
  _EnumValuesOfPriority,
  _Levels,
  _ToLevel,
  _LevelNameRet,
  _Compare,
  _NamesArray,
  _PriorityNames,
  _PriorityValues,
};
