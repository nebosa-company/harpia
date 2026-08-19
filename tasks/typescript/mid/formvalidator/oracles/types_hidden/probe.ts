import { firstError, isValid, rules, validate } from "../src/form";
import type { Errors, FieldName, Rules, Validator } from "../src/form";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

interface Signup {
  name: string;
  email: string;
  age: number;
  accepted: boolean;
  nickname?: string;
}

type _Rules = Expect<
  Equals<
    Rules<Signup>,
    {
      name: Validator<string>[];
      email: Validator<string>[];
      age: Validator<number>[];
      accepted: Validator<boolean>[];
      nickname: Validator<string | undefined>[];
    }
  >
>;

type _Errors = Expect<
  Equals<
    Errors<Signup>,
    {
      name?: string | undefined;
      email?: string | undefined;
      age?: string | undefined;
      accepted?: string | undefined;
      nickname?: string | undefined;
    }
  >
>;

type _Fields = Expect<
  Equals<FieldName<Signup>, "name" | "email" | "age" | "accepted" | "nickname">
>;

const good: Rules<Signup> = {
  name: [rules.required(), rules.minLength(2)],
  email: [rules.pattern(/@/)],
  age: [rules.range(18, 120)],
  accepted: [rules.isTrue()],
  nickname: [rules.required()],
};

const errors = validate({ name: "", email: "", age: 0, accepted: false }, {
  name: [rules.required()],
  email: [rules.required()],
  age: [rules.range(0, 1)],
  accepted: [rules.isTrue()],
});
type _Validate = Expect<
  Equals<
    typeof errors,
    {
      name?: string | undefined;
      email?: string | undefined;
      age?: string | undefined;
      accepted?: string | undefined;
    }
  >
>;
type _IsValid = Expect<Equals<ReturnType<typeof isValid<Signup>>, boolean>>;
type _First = Expect<Equals<ReturnType<typeof firstError<Signup>>, string | null>>;

declare function takeRules(table: Rules<Signup>): void;

// @ts-expect-error every field needs an entry: "accepted" is missing
takeRules({ name: [], email: [], age: [], nickname: [] });

takeRules({
  name: [],
  email: [],
  // @ts-expect-error a string rule cannot guard a number field
  age: [rules.minLength(2)],
  accepted: [rules.isTrue()],
  nickname: [],
});

takeRules({
  // @ts-expect-error a boolean rule cannot guard a string field
  name: [rules.isTrue()],
  email: [],
  age: [],
  accepted: [],
  nickname: [],
});

// @ts-expect-error "surname" is not a field of this form
firstError(errors, ["surname"]);

declare const e: Errors<Signup>;
const message: string | undefined = e.name;
void message;
// @ts-expect-error the error table has no such field
void e.surname;

void good;

export type { _Rules, _Errors, _Fields, _Validate, _IsValid, _First };
