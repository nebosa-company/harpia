// Key/value store over the block device, promise-based via async/await.

export function openStore(device) {
  const read = (key) =>
    new Promise((resolve, reject) => {
      device.readBlock(key, (err, value) => (err ? reject(err) : resolve(value)));
    });
  const write = (key, value) =>
    new Promise((resolve, reject) => {
      device.writeBlock(key, value, (err) => (err ? reject(err) : resolve()));
    });
  const del = (key) =>
    new Promise((resolve, reject) => {
      device.deleteBlock(key, (err) => (err ? reject(err) : resolve()));
    });
  const list = () =>
    new Promise((resolve, reject) => {
      device.listKeys((err, keys) => (err ? reject(err) : resolve(keys)));
    });

  const get = async (key) => read(key);

  const put = async (key, value) => {
    await write(key, value);
    return value;
  };

  const remove = async (key) => {
    await del(key);
  };

  const keys = async () => list();

  const rename = async (oldKey, newKey) => {
    const value = await read(oldKey);
    await write(newKey, value);
    await del(oldKey);
  };

  const total = async () => {
    let sum = 0;
    for (const key of await list()) {
      const value = await read(key);
      if (typeof value === "number") sum += value;
    }
    return sum;
  };

  return { get, put, remove, keys, rename, total };
}
