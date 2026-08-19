import { readFile } from "node:fs/promises";

const OPS = new Set(["$eq", "$ne", "$in", "$gt", "$gte", "$lt", "$lte"]);
const RANGE_OPS = ["$gt", "$gte", "$lt", "$lte"];

const typeRank = (v) => {
  if (v === null || v === undefined) return 0;
  if (typeof v === "number") return 1;
  if (typeof v === "string") return 2;
  if (typeof v === "boolean") return 3;
  return 4;
};

function compareValues(a, b) {
  const ra = typeRank(a);
  const rb = typeRank(b);
  if (ra !== rb) return ra < rb ? -1 : 1;
  if (ra === 0) return 0;
  if (ra === 1) return a === b ? 0 : a < b ? -1 : 1;
  if (ra === 2) return a === b ? 0 : a < b ? -1 : 1;
  if (ra === 3) return a === b ? 0 : a === false ? -1 : 1;
  return 0;
}

const fieldValue = (record, field) =>
  Object.hasOwn(record, field) && record[field] !== undefined
    ? record[field]
    : null;

function ordered(value, bound, cmp) {
  const bothNumbers = typeof value === "number" && typeof bound === "number";
  const bothStrings = typeof value === "string" && typeof bound === "string";
  if (!bothNumbers && !bothStrings) return false;
  return cmp(value, bound);
}

function conditionOps(condition) {
  if (condition === null || typeof condition !== "object") {
    return { $eq: condition };
  }
  for (const key of Object.keys(condition)) {
    if (!OPS.has(key)) {
      throw new Error(`unknown operator: ${key}`);
    }
  }
  return condition;
}

function valueMatches(value, condition) {
  const ops = conditionOps(condition);
  for (const [op, bound] of Object.entries(ops)) {
    switch (op) {
      case "$eq":
        if (value !== bound) return false;
        break;
      case "$ne":
        if (value === bound) return false;
        break;
      case "$in":
        if (!Array.isArray(bound) || !bound.some((b) => b === value)) return false;
        break;
      case "$gt":
        if (!ordered(value, bound, (a, b) => a > b)) return false;
        break;
      case "$gte":
        if (!ordered(value, bound, (a, b) => a >= b)) return false;
        break;
      case "$lt":
        if (!ordered(value, bound, (a, b) => a < b)) return false;
        break;
      case "$lte":
        if (!ordered(value, bound, (a, b) => a <= b)) return false;
        break;
      default:
        throw new Error(`unknown operator: ${op}`);
    }
  }
  return true;
}

function indexUsable(condition) {
  if (condition === null || typeof condition !== "object") return true;
  const keys = Object.keys(condition);
  return keys.some((k) => k === "$eq" || k === "$in" || RANGE_OPS.includes(k));
}

export class JsonlDatabase {
  #records = [];
  #indexes = new Map(); // field -> Map(value -> positions array)

  constructor(text) {
    if (typeof text !== "string") {
      throw new TypeError("JsonlDatabase: text must be a string");
    }
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line === "") continue;
      let parsed;
      try {
        parsed = JSON.parse(line);
      } catch {
        throw new Error(`invalid JSONL at line ${i + 1}`);
      }
      if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
        throw new Error(`invalid JSONL at line ${i + 1}: not an object`);
      }
      this.#records.push(parsed);
    }
  }

  static async fromFile(path) {
    return new JsonlDatabase(await readFile(path, "utf8"));
  }

  count() {
    return this.#records.length;
  }

  createIndex(field) {
    if (this.#indexes.has(field)) return;
    const byValue = new Map();
    this.#records.forEach((record, position) => {
      const value = fieldValue(record, field);
      let positions = byValue.get(value);
      if (!positions) {
        positions = [];
        byValue.set(value, positions);
      }
      positions.push(position);
    });
    this.#indexes.set(field, byValue);
  }

  #validate(query) {
    const { where = {}, orderBy, limit, offset, select } = query;
    for (const condition of Object.values(where)) {
      conditionOps(condition); // throws on unknown operators
    }
    if (orderBy !== undefined) {
      const dir = orderBy[1];
      if (dir !== "asc" && dir !== "desc") {
        throw new Error(`invalid orderBy direction: ${dir}`);
      }
    }
    for (const [name, v] of [["limit", limit], ["offset", offset]]) {
      if (v !== undefined && (!Number.isInteger(v) || v < 0)) {
        throw new RangeError(`${name} must be a non-negative integer`);
      }
    }
    return { where, orderBy, limit, offset: offset ?? 0, select };
  }

  #plan(where) {
    for (const field of Object.keys(where)) {
      if (!this.#indexes.has(field)) continue;
      if (!indexUsable(where[field])) continue;
      const byValue = this.#indexes.get(field);
      const positions = [];
      for (const [value, valuePositions] of byValue) {
        if (valueMatches(value, where[field])) {
          positions.push(...valuePositions);
        }
      }
      positions.sort((a, b) => a - b);
      return { index: field, positions };
    }
    return { index: null, positions: null };
  }

  explain(query = {}) {
    const { where } = this.#validate(query);
    const plan = this.#plan(where);
    return {
      index: plan.index,
      scanned: plan.index === null ? this.#records.length : plan.positions.length,
    };
  }

  find(query = {}) {
    const { where, orderBy, limit, offset, select } = this.#validate(query);
    const plan = this.#plan(where);
    const candidates =
      plan.index === null
        ? this.#records
        : plan.positions.map((p) => this.#records[p]);

    let results = candidates.filter((record) =>
      Object.entries(where).every(([field, condition]) =>
        valueMatches(fieldValue(record, field), condition),
      ),
    );

    if (orderBy !== undefined) {
      const [field, dir] = orderBy;
      const sign = dir === "desc" ? -1 : 1;
      results = results
        .map((record, i) => ({ record, i }))
        .sort((a, b) => {
          const c = compareValues(
            fieldValue(a.record, field),
            fieldValue(b.record, field),
          );
          return c !== 0 ? sign * c : a.i - b.i;
        })
        .map((x) => x.record);
    }

    results = results.slice(offset, limit === undefined ? undefined : offset + limit);

    if (select !== undefined) {
      results = results.map((record) => {
        const out = {};
        for (const field of select) {
          if (Object.hasOwn(record, field)) out[field] = record[field];
        }
        return out;
      });
    }

    return results;
  }
}
