// Pull-based streaming over async iteration.

function iterate(source) {
  if (source !== null && typeof source === "object" && typeof source[Symbol.asyncIterator] === "function") {
    return source[Symbol.asyncIterator]();
  }
  if (source !== null && source !== undefined && typeof source[Symbol.iterator] === "function") {
    return source[Symbol.iterator]();
  }
  throw new TypeError("not an iterable source");
}

export async function* fromIterable(source) {
  for await (const value of source) yield value;
}

export function map(source, fn) {
  if (typeof fn !== "function") throw new TypeError("map expects a function");
  return (async function* () {
    let index = 0;
    for await (const value of source) {
      yield await fn(value, index++);
    }
  })();
}

export function filter(source, predicate) {
  if (typeof predicate !== "function") throw new TypeError("filter expects a function");
  return (async function* () {
    let index = 0;
    for await (const value of source) {
      if (await predicate(value, index++)) yield value;
    }
  })();
}

export function take(source, n) {
  if (!Number.isInteger(n) || n < 0) {
    throw new TypeError("take expects a non-negative integer");
  }
  return (async function* () {
    if (n === 0) return;
    let taken = 0;
    for await (const value of source) {
      yield value;
      taken += 1;
      if (taken >= n) return;
    }
  })();
}

export function chunk(source, size) {
  if (!Number.isInteger(size) || size < 1) {
    throw new TypeError("chunk expects a positive integer");
  }
  return (async function* () {
    let buffer = [];
    for await (const value of source) {
      buffer.push(value);
      if (buffer.length === size) {
        yield buffer;
        buffer = [];
      }
    }
    if (buffer.length > 0) yield buffer;
  })();
}

export async function* concat(...sources) {
  for (const source of sources) {
    for await (const value of source) yield value;
  }
}

export async function* zip(a, b) {
  const left = iterate(a);
  const right = iterate(b);
  try {
    for (;;) {
      const [ra, rb] = await Promise.all([left.next(), right.next()]);
      if (ra.done || rb.done) return;
      yield [ra.value, rb.value];
    }
  } finally {
    await left.return?.();
    await right.return?.();
  }
}

export function pipeline(source, ...ops) {
  let current = source;
  for (const op of ops) {
    if (typeof op !== "function") throw new TypeError("pipeline ops must be functions");
    current = op(current);
  }
  return current;
}

export async function toArray(source) {
  const out = [];
  for await (const value of source) out.push(value);
  return out;
}

export function channel(options = {}) {
  const { capacity = Infinity } = options ?? {};
  if (typeof capacity !== "number" || Number.isNaN(capacity) || capacity <= 0) {
    throw new RangeError("capacity must be a positive number");
  }

  const buffer = [];
  const consumers = [];
  const producers = [];
  let closed = false;

  function pump() {
    for (;;) {
      while (producers.length > 0 && buffer.length < capacity) {
        const producer = producers.shift();
        buffer.push(producer.value);
        producer.resolve();
      }
      if (consumers.length === 0 || buffer.length === 0) break;
      const resolve = consumers.shift();
      resolve({ value: buffer.shift(), done: false });
    }
    if (closed && buffer.length === 0 && producers.length === 0) {
      while (consumers.length > 0) consumers.shift()({ value: undefined, done: true });
    }
  }

  const stream = {
    [Symbol.asyncIterator]() {
      return {
        [Symbol.asyncIterator]() {
          return this;
        },
        next() {
          if (buffer.length > 0) {
            const value = buffer.shift();
            pump();
            return Promise.resolve({ value, done: false });
          }
          if (closed) return Promise.resolve({ value: undefined, done: true });
          return new Promise((resolve) => {
            consumers.push(resolve);
            pump();
          });
        },
        return() {
          return Promise.resolve({ value: undefined, done: true });
        },
      };
    },
  };

  return {
    stream,
    push(value) {
      if (closed) return Promise.reject(new Error("channel is closed"));
      return new Promise((resolve) => {
        producers.push({ value, resolve });
        pump();
      });
    },
    close() {
      closed = true;
      pump();
    },
    get size() {
      return buffer.length;
    },
  };
}
