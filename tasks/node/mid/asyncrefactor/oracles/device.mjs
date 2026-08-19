// Simulated async block device. Fixed dependency — do not modify.
// Deliberately callback-based: this mirrors the vendor SDK it stands in for.

export function createDevice(initial = {}) {
  const blocks = new Map(Object.entries(initial));
  let ops = 0;
  return {
    readBlock(key, cb) {
      setImmediate(() => {
        ops += 1;
        if (!blocks.has(key)) {
          const err = new Error(`no such block: ${key}`);
          err.code = "NOT_FOUND";
          cb(err);
          return;
        }
        cb(null, blocks.get(key));
      });
    },
    writeBlock(key, value, cb) {
      setImmediate(() => {
        ops += 1;
        blocks.set(key, value);
        cb(null);
      });
    },
    deleteBlock(key, cb) {
      setImmediate(() => {
        ops += 1;
        if (!blocks.delete(key)) {
          const err = new Error(`no such block: ${key}`);
          err.code = "NOT_FOUND";
          cb(err);
          return;
        }
        cb(null);
      });
    },
    listKeys(cb) {
      setImmediate(() => {
        ops += 1;
        cb(null, [...blocks.keys()].sort());
      });
    },
    opCount() {
      return ops;
    },
  };
}
