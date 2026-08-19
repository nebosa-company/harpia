import { column, parseRows, toCsv } from "../src/csv";
import type { ColumnName, Row } from "../src/csv";

type Equals<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends <T>() => T extends Y ? 1 : 2 ? true : false;
type Expect<T extends true> = T;

type _Row = Expect<Equals<Row<["id", "name"]>, { id: string; name: string }>>;
type _RowReadonly = Expect<
  Equals<Row<readonly ["id", "name"]>, { id: string; name: string }>
>;
type _Column = Expect<Equals<ColumnName<["id", "name", "qty"]>, "id" | "name" | "qty">>;

// the row type follows from a plain array literal, with no `as const`
const rows = parseRows("id,name\n1,ada", ["id", "name"]);
type _Rows = Expect<Equals<typeof rows, { id: string; name: string }[]>>;

const first = rows[0];
const id: string = first.id;
const name: string = first.name;
void id;
void name;

// @ts-expect-error this document has no "sku" column
void first.sku;

const picked = column(rows, "name");
type _Picked = Expect<Equals<typeof picked, string[]>>;

// @ts-expect-error "sku" is not a column of these rows
column(rows, "sku");

toCsv(["id", "name"], rows);
toCsv(["id", "name"], [{ id: "1", name: "ada" }]);

// @ts-expect-error the rows must carry every column of the header
toCsv(["id", "name"], [{ id: "1" }]);

// @ts-expect-error a column value is a string
toCsv(["id", "name"], [{ id: 1, name: "ada" }]);

// @ts-expect-error these rows do not match that header
toCsv(["sku", "qty"], rows);

const wide = parseRows("a,b,c\n1,2,3", ["a", "b", "c"]);
type _Wide = Expect<Equals<typeof wide, { a: string; b: string; c: string }[]>>;
column(wide, "c");

export type { _Row, _RowReadonly, _Column, _Rows, _Picked, _Wide };
