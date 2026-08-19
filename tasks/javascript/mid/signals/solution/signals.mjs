// Synchronous, glitch-free reactive primitives.

let activeObserver = null;
let batchDepth = 0;
let flushing = false;
let nextId = 1;
const pending = new Set();

function track(node) {
  if (activeObserver === null) return;
  activeObserver.deps.add(node);
  node.subscribers.add(activeObserver);
}

function clearDeps(observer) {
  for (const dep of observer.deps) dep.subscribers.delete(observer);
  observer.deps.clear();
}

function invalidate(node) {
  for (const sub of [...node.subscribers]) {
    if (sub.kind === "computed") {
      if (!sub.dirty) {
        sub.dirty = true;
        invalidate(sub);
      }
    } else if (!sub.disposed) {
      pending.add(sub);
    }
  }
}

function runEffect(node) {
  if (node.disposed) return;
  clearDeps(node);
  const previous = activeObserver;
  activeObserver = node;
  try {
    node.fn();
  } finally {
    activeObserver = previous;
  }
}

function flush() {
  if (batchDepth > 0 || flushing) return;
  flushing = true;
  try {
    let rounds = 0;
    while (pending.size > 0) {
      rounds += 1;
      if (rounds > 1000) throw new Error("effects did not settle");
      const round = [...pending].sort((a, b) => a.id - b.id);
      pending.clear();
      for (const node of round) runEffect(node);
    }
  } finally {
    flushing = false;
  }
}

export function signal(initial) {
  const node = { kind: "signal", subscribers: new Set(), value: initial };
  return {
    get value() {
      track(node);
      return node.value;
    },
    set value(next) {
      if (Object.is(node.value, next)) return;
      node.value = next;
      invalidate(node);
      flush();
    },
  };
}

export function computed(fn) {
  if (typeof fn !== "function") throw new TypeError("computed expects a function");
  const node = {
    kind: "computed",
    subscribers: new Set(),
    deps: new Set(),
    dirty: true,
    running: false,
    value: undefined,
  };
  return {
    get value() {
      if (node.running) throw new Error("cycle detected while evaluating a computed");
      track(node);
      if (node.dirty) {
        clearDeps(node);
        const previous = activeObserver;
        activeObserver = node;
        node.running = true;
        try {
          node.value = fn();
          node.dirty = false;
        } finally {
          node.running = false;
          activeObserver = previous;
        }
      }
      return node.value;
    },
    set value(_next) {
      throw new TypeError("a computed value is read-only");
    },
  };
}

export function effect(fn) {
  if (typeof fn !== "function") throw new TypeError("effect expects a function");
  const node = { kind: "effect", id: nextId++, deps: new Set(), disposed: false, fn };
  runEffect(node);
  return () => {
    if (node.disposed) return false;
    node.disposed = true;
    clearDeps(node);
    pending.delete(node);
    return true;
  };
}

export function batch(fn) {
  if (typeof fn !== "function") throw new TypeError("batch expects a function");
  batchDepth += 1;
  try {
    return fn();
  } finally {
    batchDepth -= 1;
    if (batchDepth === 0) flush();
  }
}

export function untracked(fn) {
  if (typeof fn !== "function") throw new TypeError("untracked expects a function");
  const previous = activeObserver;
  activeObserver = null;
  try {
    return fn();
  } finally {
    activeObserver = previous;
  }
}
