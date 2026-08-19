// Counter factories for the metrics dashboard. Each widget on the page asks
// for its own counter and bumps it whenever it sees an event.

function check(n, start) {
  if (!Number.isInteger(n) || n < 0) {
    throw new TypeError("n must be a non-negative integer");
  }
  if (typeof start !== "number" || !Number.isFinite(start)) {
    throw new TypeError("start must be a finite number");
  }
}

export function makeCounters(n, start = 0) {
  check(n, start);
  const counters = [];
  for (let i = 0; i < n; i++) {
    let value = start;
    counters.push(function () {
      value += 1;
      return value;
    });
  }
  return counters;
}

export function labelCounters(n, start = 0) {
  check(n, start);
  const counters = [];
  for (let i = 0; i < n; i++) {
    let value = start;
    counters.push(function () {
      value += 1;
      return `c${i}:${value}`;
    });
  }
  return counters;
}
