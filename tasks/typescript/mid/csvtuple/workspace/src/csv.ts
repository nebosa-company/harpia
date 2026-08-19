/**
 * CSV import.
 *
 * The types below are placeholders: a row is described as "some strings
 * keyed by some strings", so the header the caller passed is forgotten
 * the moment it crosses this boundary.
 */
export type Header = readonly string[];

export type Row<H extends Header> = Record<string, string>;

export type ColumnName<H extends Header> = string;

export function parseRows<H extends Header>(text: string, header: H): Row<H>[] {
  void text;
  void header;
  throw new Error("parseRows is not implemented");
}

export function column<R extends Record<string, string>>(
  rows: readonly R[],
  key: string,
): string[] {
  void rows;
  void key;
  throw new Error("column is not implemented");
}

export function toCsv<H extends Header>(header: H, rows: readonly Row<H>[]): string {
  void header;
  void rows;
  throw new Error("toCsv is not implemented");
}
