import test from "node:test";
import assert from "node:assert/strict";
import { run } from "./vm.mjs";

test("push and stack operations", () => {
  assert.deepEqual(run([["PUSH", 1], ["PUSH", 2]]).stack, [1, 2]);
  assert.deepEqual(run([["PUSH", 1], ["PUSH", 2], ["POP"]]).stack, [1]);
  assert.deepEqual(run([["PUSH", 7], ["DUP"]]).stack, [7, 7]);
  assert.deepEqual(run([["PUSH", 1], ["PUSH", 2], ["SWAP"]]).stack, [2, 1]);
});

test("an empty program does nothing", () => {
  const result = run([]);
  assert.deepEqual(result.stack, []);
  assert.deepEqual(result.output, []);
  assert.deepEqual(result.globals, {});
});

test("arithmetic pops right then left", () => {
  assert.deepEqual(run([["PUSH", 10], ["PUSH", 3], ["SUB"]]).stack, [7]);
  assert.deepEqual(run([["PUSH", 10], ["PUSH", 3], ["ADD"]]).stack, [13]);
  assert.deepEqual(run([["PUSH", 10], ["PUSH", 3], ["MUL"]]).stack, [30]);
  assert.deepEqual(run([["PUSH", 7], ["PUSH", 2], ["DIV"]]).stack, [3.5]);
  assert.deepEqual(run([["PUSH", 10], ["PUSH", 3], ["MOD"]]).stack, [1]);
});

test("ADD concatenates two strings", () => {
  assert.deepEqual(run([["PUSH", "ab"], ["PUSH", "cd"], ["ADD"]]).stack, ["abcd"]);
});

test("comparisons and NOT push booleans", () => {
  assert.deepEqual(run([["PUSH", 1], ["PUSH", 2], ["LT"]]).stack, [true]);
  assert.deepEqual(run([["PUSH", 2], ["PUSH", 1], ["LT"]]).stack, [false]);
  assert.deepEqual(run([["PUSH", 2], ["PUSH", 1], ["GT"]]).stack, [true]);
  assert.deepEqual(run([["PUSH", "a"], ["PUSH", "a"], ["EQ"]]).stack, [true]);
  assert.deepEqual(run([["PUSH", 1], ["PUSH", 2], ["EQ"]]).stack, [false]);
  assert.deepEqual(run([["PUSH", 0], ["NOT"]]).stack, [true]);
  assert.deepEqual(run([["PUSH", "x"], ["NOT"]]).stack, [false]);
});

test("variables are stored and loaded", () => {
  const result = run([["PUSH", 5], ["STORE", "x"], ["LOAD", "x"], ["LOAD", "x"], ["ADD"]]);
  assert.deepEqual(result.stack, [10]);
  assert.deepEqual(result.globals, { x: 5 });
});

test("globals seed the program and come back", () => {
  const result = run([["LOAD", "base"], ["PUSH", 1], ["ADD"], ["STORE", "base"]], {
    globals: { base: 41 },
  });
  assert.deepEqual(result.globals, { base: 42 });
});

test("PRINT collects output in order", () => {
  const result = run([["PUSH", "a"], ["PRINT"], ["PUSH", 2], ["PRINT"], ["PUSH", true], ["PRINT"]]);
  assert.deepEqual(result.output, ["a", 2, true]);
  assert.deepEqual(result.stack, []);
});

test("jumps drive a loop", () => {
  const program = [
    ["PUSH", 0],
    ["STORE", "sum"],
    ["PUSH", 1],
    ["STORE", "i"],
    ["LABEL", "loop"],
    ["LOAD", "i"],
    ["PUSH", 11],
    ["LT"],
    ["JZ", "end"],
    ["LOAD", "sum"],
    ["LOAD", "i"],
    ["ADD"],
    ["STORE", "sum"],
    ["LOAD", "i"],
    ["PUSH", 1],
    ["ADD"],
    ["STORE", "i"],
    ["JMP", "loop"],
    ["LABEL", "end"],
    ["LOAD", "sum"],
    ["PRINT"],
  ];
  const result = run(program);
  assert.deepEqual(result.output, [55]);
  assert.equal(result.globals.i, 11);
});

test("JZ only jumps on a falsy value", () => {
  const skip = run([["PUSH", 0], ["JZ", "end"], ["PUSH", "not reached"], ["LABEL", "end"]]);
  assert.deepEqual(skip.stack, []);
  const through = run([["PUSH", 1], ["JZ", "end"], ["PUSH", "reached"], ["LABEL", "end"]]);
  assert.deepEqual(through.stack, ["reached"]);
});

test("a closure is called with arguments and returns a value", () => {
  const program = [
    ["CLOSURE", ["a", "b"], [["LOAD", "a"], ["LOAD", "b"], ["ADD"], ["RET"]]],
    ["STORE", "add"],
    ["LOAD", "add"],
    ["PUSH", 2],
    ["PUSH", 3],
    ["CALL", 2],
    ["PRINT"],
  ];
  assert.deepEqual(run(program).output, [5]);
});

test("a body that runs off the end returns null", () => {
  const program = [
    ["CLOSURE", [], [["PUSH", 1], ["POP"]]],
    ["CALL", 0],
    ["PRINT"],
  ];
  assert.deepEqual(run(program).output, [null]);
});

test("closures capture the scope they were made in", () => {
  const program = [
    ["PUSH", 10],
    ["STORE", "outer"],
    ["CLOSURE", [], [["LOAD", "outer"], ["PUSH", 5], ["ADD"], ["RET"]]],
    ["CALL", 0],
    ["PRINT"],
  ];
  assert.deepEqual(run(program).output, [15]);
});

test("recursion works", () => {
  const program = [
    [
      "CLOSURE",
      ["n"],
      [
        ["LOAD", "n"],
        ["PUSH", 2],
        ["LT"],
        ["JZ", "recurse"],
        ["PUSH", 1],
        ["RET"],
        ["LABEL", "recurse"],
        ["LOAD", "n"],
        ["LOAD", "fact"],
        ["LOAD", "n"],
        ["PUSH", 1],
        ["SUB"],
        ["CALL", 1],
        ["MUL"],
        ["RET"],
      ],
    ],
    ["STORE", "fact"],
    ["LOAD", "fact"],
    ["PUSH", 5],
    ["CALL", 1],
    ["PRINT"],
  ];
  assert.deepEqual(run(program).output, [120]);
});

test("a counter factory gives independent counters", () => {
  const program = [
    [
      "CLOSURE",
      [],
      [
        ["PUSH", 0],
        ["STORE", "count"],
        [
          "CLOSURE",
          [],
          [
            ["LOAD", "count"],
            ["PUSH", 1],
            ["ADD"],
            ["STORE", "count"],
            ["LOAD", "count"],
            ["RET"],
          ],
        ],
        ["RET"],
      ],
    ],
    ["STORE", "makeCounter"],
    ["LOAD", "makeCounter"],
    ["CALL", 0],
    ["STORE", "c1"],
    ["LOAD", "makeCounter"],
    ["CALL", 0],
    ["STORE", "c2"],
    ["LOAD", "c1"],
    ["CALL", 0],
    ["PRINT"],
    ["LOAD", "c1"],
    ["CALL", 0],
    ["PRINT"],
    ["LOAD", "c2"],
    ["CALL", 0],
    ["PRINT"],
    ["LOAD", "c1"],
    ["CALL", 0],
    ["PRINT"],
  ];
  assert.deepEqual(run(program).output, [1, 2, 1, 3]);
});

test("HALT stops everything, nested calls included", () => {
  const program = [
    ["PUSH", "kept"],
    ["CLOSURE", [], [["PUSH", "inner"], ["PRINT"], ["HALT"], ["PUSH", "unreachable"], ["PRINT"]]],
    ["CALL", 0],
    ["PUSH", "never"],
  ];
  const result = run(program);
  assert.deepEqual(result.output, ["inner"]);
  assert.deepEqual(result.stack, ["kept"]);
});

test("a closure may be passed to another closure", () => {
  const program = [
    ["CLOSURE", ["x"], [["LOAD", "x"], ["PUSH", 2], ["MUL"], ["RET"]]],
    ["STORE", "double"],
    [
      "CLOSURE",
      ["fn", "v"],
      [["LOAD", "fn"], ["LOAD", "v"], ["CALL", 1], ["LOAD", "fn"], ["SWAP"], ["CALL", 1], ["RET"]],
    ],
    ["STORE", "twice"],
    ["LOAD", "twice"],
    ["LOAD", "double"],
    ["PUSH", 3],
    ["CALL", 2],
    ["PRINT"],
  ];
  assert.deepEqual(run(program).output, [12]);
});
