import test from "node:test";
import assert from "node:assert/strict";
import { run } from "./vm.mjs";

test("stack underflow is reported", () => {
  assert.throws(() => run([["POP"]]), /underflow/i);
  assert.throws(() => run([["PUSH", 1], ["ADD"]]), /underflow/i);
  assert.throws(() => run([["DUP"]]), /underflow/i);
});

test("each frame has its own stack", () => {
  const program = [
    ["PUSH", 1],
    ["PUSH", 2],
    ["CLOSURE", [], [["POP"]]],
    ["CALL", 0],
  ];
  assert.throws(() => run(program), /underflow/i);
});

test("an unknown opcode is reported", () => {
  assert.throws(() => run([["FLY"]]), /unknown/i);
});

test("an unbound variable is a ReferenceError", () => {
  assert.throws(() => run([["LOAD", "missing"]]), ReferenceError);
  assert.throws(() => run([["CLOSURE", [], [["LOAD", "nope"], ["RET"]]], ["CALL", 0]]), ReferenceError);
});

test("division and modulo by zero are RangeErrors", () => {
  assert.throws(() => run([["PUSH", 1], ["PUSH", 0], ["DIV"]]), RangeError);
  assert.throws(() => run([["PUSH", 1], ["PUSH", 0], ["MOD"]]), RangeError);
});

test("arithmetic on the wrong types is a TypeError", () => {
  assert.throws(() => run([["PUSH", "a"], ["PUSH", 1], ["ADD"]]), TypeError);
  assert.throws(() => run([["PUSH", "a"], ["PUSH", "b"], ["SUB"]]), TypeError);
  assert.throws(() => run([["PUSH", null], ["PUSH", 1], ["MUL"]]), TypeError);
  assert.throws(() => run([["PUSH", "a"], ["PUSH", "b"], ["LT"]]), TypeError);
});

test("calling something that is not a closure is a TypeError", () => {
  assert.throws(() => run([["PUSH", 42], ["CALL", 0]]), TypeError);
  assert.throws(() => run([["PUSH", "fn"], ["PUSH", 1], ["CALL", 1]]), TypeError);
});

test("a bad argument count is a TypeError", () => {
  const closure = ["CLOSURE", [], [["PUSH", 1], ["RET"]]];
  assert.throws(() => run([closure, ["CALL", -1]]), TypeError);
  assert.throws(() => run([closure, ["CALL", 1.5]]), TypeError);
  assert.throws(() => run([closure, ["CALL", "1"]]), TypeError);
});

test("unknown and duplicate labels are reported", () => {
  assert.throws(() => run([["JMP", "nowhere"]]), /label/i);
  assert.throws(() => run([["LABEL", "a"], ["LABEL", "a"]]), /duplicate/i);
});

test("a malformed program is a TypeError", () => {
  assert.throws(() => run("not a program"), TypeError);
  assert.throws(() => run(null), TypeError);
  assert.throws(() => run([["PUSH", 1], "PUSH"]), TypeError);
  assert.throws(() => run([[42]]), TypeError);
});

test("the step limit stops an endless loop", () => {
  const program = [["LABEL", "spin"], ["JMP", "spin"]];
  assert.throws(() => run(program, { maxSteps: 50 }), /step limit/i);
  assert.throws(() => run(program), /step limit/i);
});

test("a program under the step limit finishes", () => {
  const result = run([["PUSH", 1], ["PUSH", 2], ["ADD"], ["PRINT"]], { maxSteps: 10 });
  assert.deepEqual(result.output, [3]);
});

test("missing arguments are null and extra ones are dropped", () => {
  const program = [
    ["CLOSURE", ["a", "b"], [["LOAD", "a"], ["PRINT"], ["LOAD", "b"], ["PRINT"], ["PUSH", 0], ["RET"]]],
    ["STORE", "f"],
    ["LOAD", "f"],
    ["PUSH", "only"],
    ["CALL", 1],
    ["POP"],
    ["LOAD", "f"],
    ["PUSH", "x"],
    ["PUSH", "y"],
    ["PUSH", "z"],
    ["CALL", 3],
    ["POP"],
  ];
  assert.deepEqual(run(program).output, ["only", null, "x", "y"]);
});

test("a parameter shadows an outer variable", () => {
  const program = [
    ["CLOSURE", ["x"], [["PUSH", "inner"], ["STORE", "x"], ["LOAD", "x"], ["RET"]]],
    ["STORE", "f"],
    ["LOAD", "f"],
    ["PUSH", "arg"],
    ["CALL", 1],
    ["PRINT"],
    ["LOAD", "x"],
    ["PRINT"],
  ];
  const result = run(program, { globals: { x: "global" } });
  assert.deepEqual(result.output, ["inner", "global"]);
  assert.equal(result.globals.x, "global");
});

test("a store with no local binding reaches the enclosing scope", () => {
  const program = [
    ["CLOSURE", [], [["PUSH", "changed"], ["STORE", "x"], ["PUSH", 0], ["RET"]]],
    ["CALL", 0],
    ["POP"],
    ["LOAD", "x"],
    ["PRINT"],
  ];
  const result = run(program, { globals: { x: "global" } });
  assert.deepEqual(result.output, ["changed"]);
  assert.equal(result.globals.x, "changed");
});

test("two closures made in one scope share its variables", () => {
  const program = [
    [
      "CLOSURE",
      [],
      [["LOAD", "shared"], ["PUSH", 1], ["ADD"], ["STORE", "shared"], ["PUSH", 0], ["RET"]],
    ],
    ["STORE", "inc"],
    ["CLOSURE", [], [["LOAD", "shared"], ["RET"]]],
    ["STORE", "get"],
    ["LOAD", "inc"],
    ["CALL", 0],
    ["POP"],
    ["LOAD", "inc"],
    ["CALL", 0],
    ["POP"],
    ["LOAD", "get"],
    ["CALL", 0],
    ["PRINT"],
  ];
  assert.deepEqual(run(program, { globals: { shared: 0 } }).output, [2]);
});

test("a closure keeps working after the call that made it returned", () => {
  const program = [
    [
      "CLOSURE",
      ["start"],
      [
        ["LOAD", "start"],
        ["STORE", "held"],
        ["CLOSURE", [], [["LOAD", "held"], ["RET"]]],
        ["RET"],
      ],
    ],
    ["STORE", "capture"],
    ["LOAD", "capture"],
    ["PUSH", "captured value"],
    ["CALL", 1],
    ["STORE", "reader"],
    ["LOAD", "reader"],
    ["CALL", 0],
    ["PRINT"],
  ];
  assert.deepEqual(run(program).output, ["captured value"]);
});

test("labels are local to their instruction list", () => {
  const program = [
    ["CLOSURE", [], [["JMP", "here"], ["PUSH", "skipped"], ["RET"], ["LABEL", "here"], ["PUSH", "inner"], ["RET"]]],
    ["STORE", "f"],
    ["JMP", "here"],
    ["PUSH", "skipped"],
    ["PRINT"],
    ["LABEL", "here"],
    ["LOAD", "f"],
    ["CALL", 0],
    ["PRINT"],
  ];
  assert.deepEqual(run(program).output, ["inner"]);
});

test("a label may appear in two different bodies", () => {
  const program = [
    ["CLOSURE", [], [["LABEL", "loop"], ["PUSH", "a"], ["RET"]]],
    ["STORE", "f"],
    ["CLOSURE", [], [["LABEL", "loop"], ["PUSH", "b"], ["RET"]]],
    ["STORE", "g"],
    ["LOAD", "f"],
    ["CALL", 0],
    ["PRINT"],
    ["LOAD", "g"],
    ["CALL", 0],
    ["PRINT"],
  ];
  assert.deepEqual(run(program).output, ["a", "b"]);
});

test("EQ uses Object.is", () => {
  assert.deepEqual(run([["PUSH", NaN], ["PUSH", NaN], ["EQ"]]).stack, [true]);
  assert.deepEqual(run([["PUSH", 0], ["PUSH", -0], ["EQ"]]).stack, [false]);
  assert.deepEqual(run([["PUSH", null], ["PUSH", null], ["EQ"]]).stack, [true]);
  assert.deepEqual(run([["PUSH", "1"], ["PUSH", 1], ["EQ"]]).stack, [false]);
});

test("deep recursion does not exhaust anything", () => {
  const program = [
    [
      "CLOSURE",
      ["n"],
      [
        ["LOAD", "n"],
        ["PUSH", 0],
        ["GT"],
        ["JZ", "done"],
        ["LOAD", "down"],
        ["LOAD", "n"],
        ["PUSH", 1],
        ["SUB"],
        ["CALL", 1],
        ["RET"],
        ["LABEL", "done"],
        ["PUSH", "bottom"],
        ["RET"],
      ],
    ],
    ["STORE", "down"],
    ["LOAD", "down"],
    ["PUSH", 200],
    ["CALL", 1],
    ["PRINT"],
  ];
  assert.deepEqual(run(program).output, ["bottom"]);
});

test("backward and forward jumps both work", () => {
  const program = [
    ["PUSH", 0],
    ["STORE", "n"],
    ["JMP", "check"],
    ["LABEL", "body"],
    ["LOAD", "n"],
    ["PUSH", 1],
    ["ADD"],
    ["STORE", "n"],
    ["LABEL", "check"],
    ["LOAD", "n"],
    ["PUSH", 3],
    ["LT"],
    ["JZ", "done"],
    ["JMP", "body"],
    ["LABEL", "done"],
    ["LOAD", "n"],
    ["PRINT"],
  ];
  assert.deepEqual(run(program).output, [3]);
});

test("two runs of the same program do not share state", () => {
  const program = [["LOAD", "count"], ["PUSH", 1], ["ADD"], ["STORE", "count"], ["LOAD", "count"], ["PRINT"]];
  assert.deepEqual(run(program, { globals: { count: 0 } }).output, [1]);
  assert.deepEqual(run(program, { globals: { count: 0 } }).output, [1]);
});
