// JSONL-backed query engine with secondary indexes.
// The query language, planner rules, and explain() contract are in the
// project brief.

export class JsonlDatabase {
  constructor(text) {
    throw new Error("not implemented");
  }

  static async fromFile(path) {
    throw new Error("not implemented");
  }

  count() {
    throw new Error("not implemented");
  }

  createIndex(field) {
    throw new Error("not implemented");
  }

  find(query = {}) {
    throw new Error("not implemented");
  }

  explain(query = {}) {
    throw new Error("not implemented");
  }
}
