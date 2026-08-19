import 'dart:io';

import '../lib/stack_vm.dart';

int failures = 0;

bool deepEq(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEq(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

void check(String label, Object? actual, Object? expected) {
  if (!deepEq(actual, expected)) {
    print('FAIL $label: expected $expected, got $actual');
    failures++;
  }
}

void main() {
  // Exact bytecode.
  check('assemble add', assemble('PUSH 2\nPUSH 3\nADD\nPRINT\nHALT'),
      [1, 2, 1, 3, 2, 18, 0]);
  check(
      'assemble countdown',
      assemble('PUSH 5\nloop:\nDUP\nJZ end\nDUP\nPRINT\nPUSH 1\nSUB\n'
          'JMP loop\nend:\nHALT'),
      [1, 5, 8, 15, 12, 8, 18, 1, 1, 3, 14, 2, 0]);
  check('case insensitive', assemble('push 1\nhAlT'), [1, 1, 0]);
  check('comments and blanks',
      assemble('; header\n\nPUSH 7 ; seven\n   \nHALT'), [1, 7, 0]);
  check('negative push', assemble('PUSH -3\nHALT'), [1, -3, 0]);
  check('numeric jump target', assemble('JMP 4\nPUSH 9\nHALT'), [14, 4, 1, 9, 0]);
  check('forward and back labels',
      assemble('start:\nJMP fwd\nfwd:\nJMP start\nHALT'), [14, 2, 14, 0, 0]);

  // Arithmetic and stack ops.
  final arith = runSource('PUSH 10\nPUSH 3\nSUB\nHALT');
  check('sub order', arith.stack, [7]);
  check('div truncates', runSource('PUSH -7\nPUSH 2\nDIV\nHALT').stack, [-3]);
  check('mod sign', runSource('PUSH -7\nPUSH 2\nMOD\nHALT').stack, [-1]);
  check('mul', runSource('PUSH 6\nPUSH 7\nMUL\nHALT').stack, [42]);
  check('neg', runSource('PUSH 5\nNEG\nHALT').stack, [-5]);
  check('dup', runSource('PUSH 4\nDUP\nHALT').stack, [4, 4]);
  check('drop', runSource('PUSH 1\nPUSH 2\nDROP\nHALT').stack, [1]);
  check('swap', runSource('PUSH 1\nPUSH 2\nSWAP\nHALT').stack, [2, 1]);
  check('over', runSource('PUSH 1\nPUSH 2\nOVER\nHALT').stack, [1, 2, 1]);

  // Globals.
  check('store load',
      runSource('PUSH 9\nSTORE 3\nLOAD 3\nLOAD 3\nADD\nHALT').stack, [18]);
  check('unset slot is zero', runSource('LOAD 12\nHALT').stack, [0]);

  // Control flow.
  final countdown = runSource('PUSH 5\nloop:\nDUP\nJZ end\nDUP\nPRINT\n'
      'PUSH 1\nSUB\nJMP loop\nend:\nHALT');
  check('countdown output', countdown.output, [5, 4, 3, 2, 1]);
  check('countdown stack', countdown.stack, [0]);

  final sub = runSource('PUSH 7\nCALL dbl\nPRINT\nPUSH 21\nCALL dbl\nPRINT\n'
      'HALT\ndbl:\nPUSH 2\nMUL\nRET');
  check('call ret output', sub.output, [14, 42]);
  check('call ret stack', sub.stack, <int>[]);

  final jz = runSource('PUSH 0\nJZ skip\nPUSH 111\nPRINT\nskip:\n'
      'PUSH 1\nJZ never\nPUSH 222\nPRINT\nnever:\nHALT');
  check('jz semantics', jz.output, [222]);

  // Nested calls.
  final nested = runSource('PUSH 3\nCALL quad\nPRINT\nHALT\n'
      'quad:\nCALL dbl\nCALL dbl\nRET\ndbl:\nPUSH 2\nMUL\nRET');
  check('nested calls', nested.output, [12]);

  // runProgram accepts raw bytecode directly.
  final raw = runProgram([1, 2, 1, 3, 2, 18, 0]);
  check('raw program output', raw.output, [5]);
  check('raw program stack', raw.stack, <int>[]);
  if (failures > 0) exit(1);
  print('core ok');
}
