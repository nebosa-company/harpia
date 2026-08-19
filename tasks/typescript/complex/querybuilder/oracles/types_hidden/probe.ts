import { createDatabase } from "../src/query";
import type { Database, Query } from "../src/query";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type Shop = {
  users: { id: number; name: string; age: number; active: boolean; note: string | null };
  orders: { id: number; userId: number; total: number };
};

const db: Database<Shop> = createDatabase<Shop>({ users: [], orders: [] });

const all = db.from("users").run();
type _All = Expect<
  Equals<
    typeof all,
    { id: number; name: string; age: number; active: boolean; note: string | null }[]
  >
>;

const two = db.from("users").select("id", "name").run();
type _Two = Expect<Equals<typeof two, { id: number; name: string }[]>>;

const one = db.from("users").select("age").run();
type _One = Expect<Equals<typeof one, { age: number }[]>>;

const chained = db
  .from("users")
  .where("age", ">", 30)
  .select("name", "active")
  .orderBy("name")
  .limit(2)
  .run();
type _Chained = Expect<Equals<typeof chained, { name: string; active: boolean }[]>>;

const orders = db.from("orders").select("total").run();
type _Orders = Expect<Equals<typeof orders, { total: number }[]>>;

const row = two[0];
const id: number = row.id;
void id;
// @ts-expect-error "age" was not selected
void row.age;

// @ts-expect-error "customers" is not a table of this schema
db.from("customers");

// @ts-expect-error "email" is not a column of users
db.from("users").select("id", "email");

// @ts-expect-error "email" is not a column of users
db.from("users").where("email", "=", "a@b");

// @ts-expect-error age holds numbers
db.from("users").where("age", ">", "old");

// @ts-expect-error active holds booleans
db.from("users").where("active", "=", "yes");

// @ts-expect-error "userId" belongs to orders, not users
db.from("users").where("userId", "=", 1);

// @ts-expect-error "sideways" is not a direction
db.from("users").orderBy("name", "sideways");

// @ts-expect-error "email" is not a column of users
db.from("users").orderBy("email");

// @ts-expect-error "~" is not an operator
db.from("users").where("age", "~", 1);

// a nullable column accepts null and its own type
db.from("users").where("note", "=", null);
db.from("users").where("note", "=", "vip");

// @ts-expect-error note holds strings or null, not numbers
db.from("users").where("note", "=", 1);

declare const q: Query<Shop, "users", "id" | "name">;
type _Run = Expect<Equals<ReturnType<typeof q.run>, { id: number; name: string }[]>>;
type _Sql = Expect<Equals<ReturnType<typeof q.toSql>, string>>;

export type { _All, _Two, _One, _Chained, _Orders, _Run, _Sql };
