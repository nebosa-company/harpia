// Cooperative scheduler over generator tasks and virtual rounds.

const TAG = Symbol("scheduler.instruction");

export function sleep(rounds) {
  if (!Number.isInteger(rounds) || rounds < 0) {
    throw new TypeError("sleep expects a non-negative integer");
  }
  return { [TAG]: "sleep", rounds };
}

export function send(channel, value) {
  if (typeof channel !== "string") throw new TypeError("send expects a channel name");
  return { [TAG]: "send", channel, value };
}

export function receive(channel) {
  if (typeof channel !== "string") throw new TypeError("receive expects a channel name");
  return { [TAG]: "receive", channel };
}

export function join(id) {
  if (!Number.isInteger(id) || id < 1) throw new TypeError("join expects a task id");
  return { [TAG]: "join", id };
}

export function fork(genFn, ...args) {
  if (typeof genFn !== "function") throw new TypeError("fork expects a generator function");
  return { [TAG]: "fork", genFn, args };
}

export function createScheduler() {
  const tasks = [];
  const channels = new Map();
  let nextId = 1;

  function queueFor(name) {
    let q = channels.get(name);
    if (!q) {
      q = [];
      channels.set(name, q);
    }
    return q;
  }

  function spawn(genFn, ...args) {
    if (typeof genFn !== "function") {
      throw new TypeError("spawn expects a generator function");
    }
    const gen = genFn(...args);
    if (!gen || typeof gen.next !== "function") {
      throw new TypeError("spawn expects a generator function");
    }
    const task = {
      id: nextId++,
      gen,
      status: "running",
      value: undefined,
      error: undefined,
      resume: undefined,
      wakeRound: 0,
      waiting: null,
    };
    tasks.push(task);
    return task.id;
  }

  function byId(id) {
    return tasks.find((t) => t.id === id);
  }

  function step(task, round, injected) {
    let result;
    try {
      result = injected === undefined ? task.gen.next(task.resume) : task.gen.throw(injected);
    } catch (err) {
      task.status = "failed";
      task.error = err;
      return;
    }
    task.resume = undefined;
    if (result.done) {
      task.status = "done";
      task.value = result.value;
      return;
    }
    const ins = result.value;
    const kind = ins !== null && typeof ins === "object" ? ins[TAG] : undefined;
    switch (kind) {
      case "sleep":
        task.wakeRound = round + 1 + ins.rounds;
        break;
      case "send":
        queueFor(ins.channel).push(ins.value);
        break;
      case "receive":
        task.waiting = { kind: "receive", channel: ins.channel };
        break;
      case "join":
        task.waiting = { kind: "join", id: ins.id };
        break;
      case "fork":
        task.resume = spawn(ins.genFn, ...ins.args);
        break;
      default:
        break;
    }
  }

  function run({ maxRounds = 10000 } = {}) {
    let round = 0;
    for (;;) {
      const active = tasks.filter((t) => t.status === "running");
      if (active.length === 0) break;
      round += 1;
      if (round > maxRounds) {
        throw new Error(`scheduler exceeded maxRounds (${maxRounds})`);
      }
      let progressed = false;
      let sleeping = false;
      for (const task of active) {
        if (task.status !== "running") continue;
        if (task.wakeRound > round) {
          sleeping = true;
          continue;
        }
        const waiting = task.waiting;
        if (waiting && waiting.kind === "receive") {
          const q = queueFor(waiting.channel);
          if (q.length === 0) continue;
          task.waiting = null;
          task.resume = q.shift();
          step(task, round);
          progressed = true;
          continue;
        }
        if (waiting && waiting.kind === "join") {
          const target = byId(waiting.id);
          if (!target) {
            task.waiting = null;
            step(task, round, new RangeError(`unknown task ${waiting.id}`));
            progressed = true;
            continue;
          }
          if (target.status === "done") {
            task.waiting = null;
            task.resume = target.value;
            step(task, round);
            progressed = true;
            continue;
          }
          if (target.status === "failed") {
            task.waiting = null;
            step(task, round, target.error);
            progressed = true;
            continue;
          }
          continue;
        }
        step(task, round);
        progressed = true;
      }
      if (!progressed && !sleeping) {
        for (const t of tasks) {
          if (t.status === "running") t.status = "blocked";
        }
        break;
      }
    }
    return {
      rounds: round,
      tasks: tasks.map((t) => ({
        id: t.id,
        status: t.status,
        value: t.status === "done" ? t.value : undefined,
        error: t.status === "failed" ? t.error : undefined,
      })),
    };
  }

  return {
    spawn,
    run,
    queued: (channel) => [...queueFor(channel)],
  };
}
