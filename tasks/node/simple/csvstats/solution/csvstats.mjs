function parseRecords(text) {
  if (typeof text !== "string") {
    throw new TypeError("parseCsv: text must be a string");
  }
  const rows = [];
  let row = [];
  let field = "";
  let inQuotes = false;
  let started = false; // has the current record any content?
  let i = 0;
  const endField = () => {
    row.push(field);
    field = "";
  };
  const endRow = () => {
    endField();
    rows.push(row);
    row = [];
    started = false;
  };
  while (i < text.length) {
    const ch = text[i];
    if (inQuotes) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 2;
          continue;
        }
        inQuotes = false;
        i += 1;
        continue;
      }
      field += ch;
      i += 1;
      continue;
    }
    if (ch === '"') {
      inQuotes = true;
      started = true;
      i += 1;
      continue;
    }
    if (ch === ",") {
      endField();
      started = true;
      i += 1;
      continue;
    }
    if (ch === "\r" && text[i + 1] === "\n") {
      endRow();
      i += 2;
      continue;
    }
    if (ch === "\n") {
      endRow();
      i += 1;
      continue;
    }
    field += ch;
    started = true;
    i += 1;
  }
  if (started || field !== "" || row.length > 0) {
    endRow();
  }
  return rows;
}

export function parseCsv(text) {
  const records = parseRecords(text);
  if (records.length === 0) return [];
  const header = records[0];
  return records.slice(1).map((r) => {
    const obj = {};
    header.forEach((h, idx) => {
      obj[h] = idx < r.length ? r[idx] : "";
    });
    return obj;
  });
}

export function columnStats(text, column) {
  const records = parseRecords(text);
  const header = records[0] ?? [];
  if (!header.includes(column)) {
    throw new RangeError(`unknown column: ${column}`);
  }
  const idx = header.indexOf(column);
  const values = [];
  for (const r of records.slice(1)) {
    const cell = (r[idx] ?? "").trim();
    if (cell === "") continue;
    const n = Number(cell);
    if (!Number.isFinite(n)) continue;
    values.push(n);
  }
  const count = values.length;
  if (count === 0) {
    return { count: 0, min: null, max: null, mean: null, median: null };
  }
  const sorted = [...values].sort((a, b) => a - b);
  const mean = values.reduce((a, b) => a + b, 0) / count;
  const median =
    count % 2 === 1
      ? sorted[(count - 1) / 2]
      : (sorted[count / 2 - 1] + sorted[count / 2]) / 2;
  return { count, min: sorted[0], max: sorted[count - 1], mean, median };
}
