// Key/value store over the block device. Error-first callbacks throughout.

export function openStore(device) {
  return {
    get(key, cb) {
      device.readBlock(key, (err, value) => {
        if (err) return cb(err);
        cb(null, value);
      });
    },
    put(key, value, cb) {
      device.writeBlock(key, value, (err) => {
        if (err) return cb(err);
        cb(null, value);
      });
    },
    remove(key, cb) {
      device.deleteBlock(key, (err) => {
        if (err) return cb(err);
        cb(null);
      });
    },
    keys(cb) {
      device.listKeys(cb);
    },
    rename(oldKey, newKey, cb) {
      device.readBlock(oldKey, (err, value) => {
        if (err) return cb(err);
        device.writeBlock(newKey, value, (err2) => {
          if (err2) return cb(err2);
          device.deleteBlock(oldKey, (err3) => {
            if (err3) return cb(err3);
            cb(null);
          });
        });
      });
    },
    total(cb) {
      device.listKeys((err, keys) => {
        if (err) return cb(err);
        let sum = 0;
        let index = 0;
        const step = () => {
          if (index >= keys.length) return cb(null, sum);
          device.readBlock(keys[index], (err2, value) => {
            if (err2) return cb(err2);
            if (typeof value === "number") sum += value;
            index += 1;
            step();
          });
        };
        step();
      });
    },
  };
}
