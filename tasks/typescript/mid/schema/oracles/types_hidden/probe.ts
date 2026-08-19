import { s } from "../src/schema";
import type { Infer, ParseResult, Schema } from "../src/schema";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _String = Expect<Equals<Infer<ReturnType<typeof s.string>>, string>>;
type _Number = Expect<Equals<Infer<ReturnType<typeof s.number>>, number>>;
type _Boolean = Expect<Equals<Infer<ReturnType<typeof s.boolean>>, boolean>>;

const literalSchema = s.literal("admin");
type _Literal = Expect<Equals<Infer<typeof literalSchema>, "admin">>;
const numberLiteral = s.literal(3);
type _NumberLiteral = Expect<Equals<Infer<typeof numberLiteral>, 3>>;

const listSchema = s.array(s.string());
type _Array = Expect<Equals<Infer<typeof listSchema>, string[]>>;

const optionalSchema = s.optional(s.number());
type _Optional = Expect<Equals<Infer<typeof optionalSchema>, number | undefined>>;

const unionSchema = s.union(s.literal("admin"), s.literal("member"));
type _Union = Expect<Equals<Infer<typeof unionSchema>, "admin" | "member">>;

const userSchema = s.object({
  id: s.number(),
  name: s.string(),
  role: s.union(s.literal("admin"), s.literal("member")),
  tags: s.array(s.string()),
  nickname: s.optional(s.string()),
  active: s.boolean(),
});

type User = Infer<typeof userSchema>;

type _User = Expect<
  Equals<
    User,
    {
      id: number;
      name: string;
      role: "admin" | "member";
      tags: string[];
      nickname?: string | undefined;
      active: boolean;
    }
  >
>;

const nested = s.object({ user: s.object({ tags: s.array(s.number()) }) });
type _Nested = Expect<Equals<Infer<typeof nested>, { user: { tags: number[] } }>>;

type _Parse = Expect<Equals<ReturnType<typeof userSchema.parse>, ParseResult<User>>>;

const result = userSchema.parse({});
if (result.ok) {
  const id: number = result.value.id;
  const role: "admin" | "member" = result.value.role;
  void id;
  void role;
  // @ts-expect-error the parsed value has no such field
  void result.value.email;
  // @ts-expect-error nickname is optional, so it may be undefined
  const nick: string = result.value.nickname;
  void nick;
} else {
  const path: (string | number)[] = result.issues[0]!.path;
  void path;
  // @ts-expect-error a failed result carries no value
  void result.value;
}

// @ts-expect-error a Schema<string> is not a Schema<number>
const wrong: Schema<number> = s.string();
void wrong;

// @ts-expect-error the literal type is kept, so "member" is not assignable
const wrongLiteral: Schema<"admin"> = s.literal("member");
void wrongLiteral;

export type {
  _String,
  _Number,
  _Boolean,
  _Literal,
  _NumberLiteral,
  _Array,
  _Optional,
  _Union,
  _User,
  _Nested,
  _Parse,
};
