// Counter factories for the metrics dashboard. Each widget on the page asks
// for its own counter and bumps it whenever it sees an event.

export function makeCounters(n, start = 0) {
  const counters = [];
  var value = start;
  for (var i = 0; i < n; i++) {
    counters.push(function () {
      value += 1;
      return value;
    });
  }
  return counters;
}

export function labelCounters(n, start = 0) {
  const counters = [];
  var value = start;
  for (var i = 0; i < n; i++) {
    counters.push(function () {
      value += 1;
      return "c" + i + ":" + value;
    });
  }
  return counters;
}
