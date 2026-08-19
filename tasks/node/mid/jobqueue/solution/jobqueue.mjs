export function createQueue(options = {}) {
  const {
    concurrency = 1,
    maxRetries = 0,
    baseDelayMs = 0,
    schedule = (fn, ms) => setTimeout(fn, ms),
  } = options;

  const waiting = []; // { job, attempt, resolve, reject }
  let running = 0;
  let delayPending = 0;
  const idleResolvers = [];

  const checkIdle = () => {
    if (waiting.length === 0 && running === 0 && delayPending === 0) {
      while (idleResolvers.length > 0) idleResolvers.shift()();
    }
  };

  const pump = () => {
    while (running < concurrency && waiting.length > 0) {
      const entry = waiting.shift();
      running += 1;
      run(entry);
    }
    checkIdle();
  };

  async function run(entry) {
    try {
      const value = await entry.job(entry.attempt);
      running -= 1;
      entry.resolve(value);
      pump();
    } catch (err) {
      running -= 1;
      if (entry.attempt <= maxRetries) {
        const delay = baseDelayMs * 2 ** (entry.attempt - 1);
        delayPending += 1;
        schedule(() => {
          delayPending -= 1;
          waiting.push({ ...entry, attempt: entry.attempt + 1 });
          pump();
        }, delay);
        pump();
      } else {
        entry.reject(err);
        pump();
      }
    }
  }

  return {
    push(job) {
      return new Promise((resolve, reject) => {
        waiting.push({ job, attempt: 1, resolve, reject });
        pump();
      });
    },
    size: () => waiting.length,
    active: () => running,
    onIdle() {
      return new Promise((resolve) => {
        idleResolvers.push(resolve);
        checkIdle();
      });
    },
  };
}
