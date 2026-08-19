// A promise implementation written from scratch, scheduled on the microtask
// queue.

const PENDING = "pending";
const FULFILLED = "fulfilled";
const REJECTED = "rejected";

export class MyPromise {
  #state = PENDING;
  #value = undefined;
  #handlers = [];
  #locked = false;

  constructor(executor) {
    if (typeof executor !== "function") {
      throw new TypeError("MyPromise: executor must be a function");
    }
    try {
      executor(
        (value) => this.#resolve(value),
        (reason) => this.#rejectOnce(reason),
      );
    } catch (err) {
      this.#rejectOnce(err);
    }
  }

  #resolve(value) {
    if (this.#locked) return;
    this.#locked = true;
    this.#adopt(value);
  }

  #rejectOnce(reason) {
    if (this.#locked) return;
    this.#locked = true;
    this.#settle(REJECTED, reason);
  }

  #adopt(value) {
    if (value === this) {
      this.#settle(REJECTED, new TypeError("Chaining cycle detected for promise"));
      return;
    }
    if (value !== null && (typeof value === "object" || typeof value === "function")) {
      let then;
      try {
        then = value.then;
      } catch (err) {
        this.#settle(REJECTED, err);
        return;
      }
      if (typeof then === "function") {
        let called = false;
        try {
          then.call(
            value,
            (v) => {
              if (called) return;
              called = true;
              this.#adopt(v);
            },
            (r) => {
              if (called) return;
              called = true;
              this.#settle(REJECTED, r);
            },
          );
        } catch (err) {
          if (!called) {
            called = true;
            this.#settle(REJECTED, err);
          }
        }
        return;
      }
    }
    this.#settle(FULFILLED, value);
  }

  #settle(state, value) {
    if (this.#state !== PENDING) return;
    this.#state = state;
    this.#value = value;
    const handlers = this.#handlers;
    this.#handlers = [];
    for (const run of handlers) queueMicrotask(run);
  }

  then(onFulfilled, onRejected) {
    return new MyPromise((resolve, reject) => {
      const run = () => {
        const handler = this.#state === FULFILLED ? onFulfilled : onRejected;
        if (typeof handler !== "function") {
          if (this.#state === FULFILLED) resolve(this.#value);
          else reject(this.#value);
          return;
        }
        try {
          resolve(handler(this.#value));
        } catch (err) {
          reject(err);
        }
      };
      if (this.#state === PENDING) this.#handlers.push(run);
      else queueMicrotask(run);
    });
  }

  catch(onRejected) {
    return this.then(undefined, onRejected);
  }

  finally(onFinally) {
    if (typeof onFinally !== "function") {
      return this.then(onFinally, onFinally);
    }
    return this.then(
      (value) => MyPromise.resolve(onFinally()).then(() => value),
      (reason) =>
        MyPromise.resolve(onFinally()).then(() => {
          throw reason;
        }),
    );
  }

  static resolve(value) {
    if (value instanceof MyPromise) return value;
    return new MyPromise((resolve) => resolve(value));
  }

  static reject(reason) {
    return new MyPromise((_resolve, reject) => reject(reason));
  }

  static all(iterable) {
    return new MyPromise((resolve, reject) => {
      const entries = [...iterable];
      const values = new Array(entries.length);
      let outstanding = entries.length;
      if (outstanding === 0) {
        resolve([]);
        return;
      }
      entries.forEach((entry, i) => {
        MyPromise.resolve(entry).then((value) => {
          values[i] = value;
          outstanding -= 1;
          if (outstanding === 0) resolve(values);
        }, reject);
      });
    });
  }

  static race(iterable) {
    return new MyPromise((resolve, reject) => {
      for (const entry of iterable) {
        MyPromise.resolve(entry).then(resolve, reject);
      }
    });
  }
}
