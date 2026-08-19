/** CSV import whose row type follows the header tuple. */
export type Header = readonly string[];

export type ColumnName<H extends Header> = H[number];

export type Row<H extends Header> = { [K in H[number]]: string };

/** Split CSV text into records of raw fields. */
function records(text: string): string[][] {
  const out: string[][] = [];
  let row: string[] = [];
  let field = "";
  let quoted = false;
  let started = false;

  const endField = (): void => {
    row.push(field);
    field = "";
  };
  const endRow = (): void => {
    endField();
    out.push(row);
    row = [];
  };

  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i] as string;
    started = true;
    if (quoted) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          quoted = false;
        }
      } else {
        field += ch;
      }
      continue;
    }
    if (ch === '"' && field === "") {
      quoted = true;
    } else if (ch === ",") {
      endField();
    } else if (ch === "\n") {
      endRow();
    } else if (ch === "\r" && text[i + 1] === "\n") {
      endRow();
      i += 1;
    } else {
      field += ch;
    }
  }
  if (started && (field !== "" || row.length > 0 || quoted)) {
    endRow();
  }
  return out;
}

export function parseRows<const H extends Header>(text: string, header: H): Row<H>[] {
  if (header.length === 0) {
    throw new TypeError("header must not be empty");
  }
  const all = records(text);
  if (all.length === 0) return [];
  const found = all[0] as string[];
  const same =
    found.length === header.length && header.every((name, i) => found[i] === name);
  if (!same) {
    throw new TypeError(
      `header mismatch: expected ${header.join(",")} but found ${found.join(",")}`,
    );
  }
  return all.slice(1).map((fields) => {
    const row: Record<string, string> = {};
    header.forEach((name, i) => {
      row[name] = fields[i] ?? "";
    });
    return row as Row<H>;
  });
}

export function column<R extends Record<string, string>, K extends keyof R & string>(
  rows: readonly R[],
  key: K,
): string[] {
  return rows.map((row) => (row as Record<string, string>)[key] ?? "");
}

function quote(field: string): string {
  return /[",\r\n]/.test(field) ? `"${field.replaceAll('"', '""')}"` : field;
}

export function toCsv<const H extends Header>(header: H, rows: readonly Row<H>[]): string {
  const lines: string[] = [header.map(quote).join(",")];
  for (const row of rows) {
    const bag = row as Record<string, string | undefined>;
    lines.push(header.map((name) => quote(bag[name] ?? "")).join(","));
  }
  return lines.join("\n");
}
