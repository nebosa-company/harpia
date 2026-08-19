import { test } from "node:test";
import assert from "node:assert/strict";
import { column, parseRows, toCsv } from "../src/csv";

test("a simple document parses into keyed rows", () => {
  const rows = parseRows("id,name\n1,ada\n2,grace", ["id", "name"]);
  assert.deepEqual(rows, [
    { id: "1", name: "ada" },
    { id: "2", name: "grace" },
  ]);
});

test("CRLF and a trailing newline are handled", () => {
  assert.deepEqual(parseRows("id,name\r\n1,ada\r\n", ["id", "name"]), [
    { id: "1", name: "ada" },
  ]);
  assert.deepEqual(parseRows("id,name\n1,ada\n", ["id", "name"]), [
    { id: "1", name: "ada" },
  ]);
  assert.deepEqual(parseRows("id,name\n1,ada\r\n2,grace\n", ["id", "name"]), [
    { id: "1", name: "ada" },
    { id: "2", name: "grace" },
  ]);
});

test("quoted fields carry commas, newlines and doubled quotes", () => {
  const text = 'id,note\n1,"a,b"\n2,"line1\nline2"\n3,"say ""hi"""';
  assert.deepEqual(parseRows(text, ["id", "note"]), [
    { id: "1", note: "a,b" },
    { id: "2", note: "line1\nline2" },
    { id: "3", note: 'say "hi"' },
  ]);
});

test("unquoted fields keep their spaces, and empty fields stay empty", () => {
  assert.deepEqual(parseRows("a,b\n x , \n,", ["a", "b"]), [
    { a: " x ", b: " " },
    { a: "", b: "" },
  ]);
});

test("short records are padded and long ones are trimmed", () => {
  assert.deepEqual(parseRows("a,b,c\n1\n1,2,3,4", ["a", "b", "c"]), [
    { a: "1", b: "", c: "" },
    { a: "1", b: "2", c: "3" },
  ]);
});

test("empty text and a header-only document yield no rows", () => {
  assert.deepEqual(parseRows("", ["id"]), []);
  assert.deepEqual(parseRows("id", ["id"]), []);
  assert.deepEqual(parseRows("id\n", ["id"]), []);
});

test("a mismatched header is a TypeError naming both lists", () => {
  assert.throws(
    () => parseRows("sku,name\n1,ada", ["id", "name"]),
    (err: unknown) =>
      err instanceof TypeError &&
      err.message === "header mismatch: expected id,name but found sku,name",
  );
  assert.throws(
    () => parseRows("name,id\n1,ada", ["id", "name"]),
    (err: unknown) =>
      err instanceof TypeError &&
      err.message === "header mismatch: expected id,name but found name,id",
  );
  assert.throws(
    () => parseRows("id\n1", ["id", "name"]),
    (err: unknown) =>
      err instanceof TypeError &&
      err.message === "header mismatch: expected id,name but found id",
  );
});

test("an empty header is refused", () => {
  assert.throws(
    () => parseRows("id\n1", []),
    (err: unknown) =>
      err instanceof TypeError && err.message === "header must not be empty",
  );
});

test("column pulls one field in row order", () => {
  const rows = parseRows("id,name\n1,ada\n2,grace", ["id", "name"]);
  assert.deepEqual(column(rows, "name"), ["ada", "grace"]);
  assert.deepEqual(column(rows, "id"), ["1", "2"]);
  assert.deepEqual(column([], "id"), []);
});

test("toCsv writes a header and one record per row", () => {
  assert.equal(
    toCsv(["id", "name"], [
      { id: "1", name: "ada" },
      { id: "2", name: "grace" },
    ]),
    "id,name\n1,ada\n2,grace",
  );
  assert.equal(toCsv(["id", "name"], []), "id,name");
});

test("toCsv quotes only what needs quoting", () => {
  assert.equal(
    toCsv(["a", "b"], [{ a: "plain", b: "with,comma" }]),
    'a,b\nplain,"with,comma"',
  );
  assert.equal(toCsv(["a"], [{ a: 'say "hi"' }]), 'a\n"say ""hi"""');
  assert.equal(toCsv(["a"], [{ a: "line1\nline2" }]), 'a\n"line1\nline2"');
  assert.equal(toCsv(["a"], [{ a: " spaced " }]), "a\n spaced ");
  assert.equal(toCsv(["a"], [{ a: "" }]), "a\n");
});

test("toCsv and parseRows round-trip", () => {
  const rows = [
    { id: "1", note: 'a,b "c"' },
    { id: "2", note: "line1\nline2" },
    { id: "3", note: "" },
  ];
  const text = toCsv(["id", "note"], rows);
  assert.deepEqual(parseRows(text, ["id", "note"]), rows);
});
