// A stack machine with lexical scopes and first-class closures.

const CLOSURE = Symbol("vm.closure");
const labelCache = new WeakMap();

function labelsOf(code) {
  const cached = labelCache.get(code);
  if (cached) return cached;
  if (!Array.isArray(code)) throw new TypeError("an instruction list must be an array");
  const labels = new Map();
  code.forEach((instruction, index) => {
    if (!Array.isArray(instruction) || typeof instruction[0] !== "string") {
      throw new TypeError(`instruction ${index} is not [opcode, ...args]`);
    }
    if (instruction[0] === "LABEL") {
      const name = instruction[1];
      if (labels.has(name)) throw new Error(`duplicate label ${String(name)}`);
      labels.set(name, index);
    }
  });
  labelCache.set(code, labels);
  return labels;
}

function makeScope(parent) {
  return { vars: new Map(), parent };
}

function lookup(scope, name) {
  for (let s = scope; s !== null; s = s.parent) {
    if (s.vars.has(name)) return s.vars.get(name);
  }
  throw new ReferenceError(`${String(name)} is not defined`);
}

function assign(scope, name, value) {
  for (let s = scope; s !== null; s = s.parent) {
    if (s.vars.has(name)) {
      s.vars.set(name, value);
      return;
    }
  }
  scope.vars.set(name, value);
}

function makeFrame(code, scope) {
  return { code, labels: labelsOf(code), pc: 0, stack: [], scope };
}

function isClosure(value) {
  return value !== null && typeof value === "object" && value[CLOSURE] === true;
}

export function run(program, options = {}) {
  const { globals = {}, maxSteps = 100000 } = options ?? {};
  if (!Array.isArray(program)) throw new TypeError("program must be an array");
  if (!Number.isInteger(maxSteps) || maxSteps < 1) {
    throw new TypeError("maxSteps must be a positive integer");
  }

  const globalScope = makeScope(null);
  for (const [name, value] of Object.entries(globals ?? {})) globalScope.vars.set(name, value);

  const root = makeFrame(program, globalScope);
  const frames = [root];
  const output = [];
  let steps = 0;

  const pop = (frame) => {
    if (frame.stack.length === 0) throw new Error("stack underflow");
    return frame.stack.pop();
  };
  const numbers = (frame, op) => {
    const right = pop(frame);
    const left = pop(frame);
    if (typeof left !== "number" || typeof right !== "number") {
      throw new TypeError(`${op} expects two numbers`);
    }
    return [left, right];
  };
  const jumpTo = (frame, label) => {
    if (!frame.labels.has(label)) throw new Error(`unknown label ${String(label)}`);
    frame.pc = frame.labels.get(label);
  };
  const returnValue = (value) => {
    frames.pop();
    if (frames.length > 0) frames[frames.length - 1].stack.push(value);
  };

  running: while (frames.length > 0) {
    const frame = frames[frames.length - 1];
    if (frame.pc >= frame.code.length) {
      returnValue(null);
      continue;
    }
    steps += 1;
    if (steps > maxSteps) throw new Error(`step limit exceeded (${maxSteps})`);

    const instruction = frame.code[frame.pc];
    frame.pc += 1;
    const [op] = instruction;

    switch (op) {
      case "PUSH":
        frame.stack.push(instruction[1]);
        break;
      case "POP":
        pop(frame);
        break;
      case "DUP": {
        const value = pop(frame);
        frame.stack.push(value, value);
        break;
      }
      case "SWAP": {
        const top = pop(frame);
        const under = pop(frame);
        frame.stack.push(top, under);
        break;
      }
      case "ADD": {
        const right = pop(frame);
        const left = pop(frame);
        if (typeof left === "string" && typeof right === "string") {
          frame.stack.push(left + right);
          break;
        }
        if (typeof left !== "number" || typeof right !== "number") {
          throw new TypeError("ADD expects two numbers or two strings");
        }
        frame.stack.push(left + right);
        break;
      }
      case "SUB": {
        const [a, b] = numbers(frame, "SUB");
        frame.stack.push(a - b);
        break;
      }
      case "MUL": {
        const [a, b] = numbers(frame, "MUL");
        frame.stack.push(a * b);
        break;
      }
      case "DIV": {
        const [a, b] = numbers(frame, "DIV");
        if (b === 0) throw new RangeError("division by zero");
        frame.stack.push(a / b);
        break;
      }
      case "MOD": {
        const [a, b] = numbers(frame, "MOD");
        if (b === 0) throw new RangeError("modulo by zero");
        frame.stack.push(a % b);
        break;
      }
      case "LT": {
        const [a, b] = numbers(frame, "LT");
        frame.stack.push(a < b);
        break;
      }
      case "GT": {
        const [a, b] = numbers(frame, "GT");
        frame.stack.push(a > b);
        break;
      }
      case "EQ": {
        const right = pop(frame);
        const left = pop(frame);
        frame.stack.push(Object.is(left, right));
        break;
      }
      case "NOT":
        frame.stack.push(!pop(frame));
        break;
      case "LABEL":
        break;
      case "JMP":
        jumpTo(frame, instruction[1]);
        break;
      case "JZ":
        if (!pop(frame)) jumpTo(frame, instruction[1]);
        break;
      case "LOAD":
        frame.stack.push(lookup(frame.scope, instruction[1]));
        break;
      case "STORE":
        assign(frame.scope, instruction[1], pop(frame));
        break;
      case "CLOSURE": {
        const params = instruction[1] ?? [];
        const body = instruction[2];
        if (!Array.isArray(params) || !Array.isArray(body)) {
          throw new TypeError("CLOSURE expects a parameter list and a body");
        }
        const closure = { params, body, scope: frame.scope };
        Object.defineProperty(closure, CLOSURE, { value: true });
        frame.stack.push(closure);
        break;
      }
      case "CALL": {
        const argc = instruction[1];
        if (!Number.isInteger(argc) || argc < 0) {
          throw new TypeError("CALL expects a non-negative argument count");
        }
        const args = [];
        for (let i = 0; i < argc; i++) args.unshift(pop(frame));
        const callee = pop(frame);
        if (!isClosure(callee)) throw new TypeError("CALL expects a closure");
        const scope = makeScope(callee.scope);
        callee.params.forEach((name, i) => {
          scope.vars.set(name, i < args.length ? args[i] : null);
        });
        frames.push(makeFrame(callee.body, scope));
        break;
      }
      case "RET":
        returnValue(pop(frame));
        break;
      case "PRINT":
        output.push(pop(frame));
        break;
      case "HALT":
        break running;
      default:
        throw new Error(`unknown opcode ${String(op)}`);
    }
  }

  return {
    stack: [...root.stack],
    output,
    globals: Object.fromEntries(globalScope.vars),
  };
}
