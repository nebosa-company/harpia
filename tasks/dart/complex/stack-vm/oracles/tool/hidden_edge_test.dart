import 'dart:io';

import '../lib/stack_vm.dart';

int failures = 0;

void check(String label, Object? actual, Object? expected) {
  if (actual != expected) {
    print('FAIL $label: expected $expected, got $actual');
    failures++;
  }
}

void expectThrows<T>(String label, void Function() fn) {
  try {
    fn();
    print('FAIL $label: expected $T, nothing thrown');
    failures++;
  } on Object catch (e) {
    if (e is! T) {
      print('FAIL $label: expected $T, got ${e.runtimeType}');
      failures++;
    }
  }
}

void main() {
  // Assembler errors.
  expectThrows<FormatException>('unknown mnemonic', () => assemble('BLORP'));
  expectThrows<FormatException>('missing operand', () => assemble('PUSH'));
  expectThrows<FormatException>('extra operand', () => assemble('ADD 1'));
  expectThrows<FormatException>(
      'extra operand on push', () => assemble('PUSH 1 2'));
  expectThrows<FormatException>('bad operand', () => assemble('PUSH abc'));
  expectThrows<FormatException>(
      'duplicate label', () => assemble('x:\nHALT\nx:\nHALT'));
  expectThrows<FormatException>(
      'undefined label', () => assemble('JMP nowhere\nHALT'));
  expectThrows<FormatException>(
      'negative slot', () => assemble('LOAD -1\nHALT'));
  expectThrows<FormatException>(
      'negative store slot', () => assemble('STORE -2\nHALT'));
  expectThrows<FormatException>('bad label chars', () => assemble('9lives:'));

  // Runtime faults.
  expectThrows<StateError>('underflow add', () => runSource('ADD\nHALT'));
  expectThrows<StateError>(
      'underflow one operand', () => runSource('PUSH 1\nADD\nHALT'));
  expectThrows<StateError>('underflow print', () => runSource('PRINT\nHALT'));
  expectThrows<StateError>(
      'underflow over', () => runSource('PUSH 1\nOVER\nHALT'));
  expectThrows<StateError>(
      'div by zero', () => runSource('PUSH 1\nPUSH 0\nDIV\nHALT'));
  expectThrows<StateError>(
      'mod by zero', () => runSource('PUSH 1\nPUSH 0\nMOD\nHALT'));
  expectThrows<StateError>('ret without call', () => runSource('RET\nHALT'));
  expectThrows<StateError>('no halt', () => runSource('PUSH 1'));
  expectThrows<StateError>(
      'jump out of range', () => runSource('JMP 99\nHALT'));
  expectThrows<StateError>('unknown opcode', () => runProgram([99, 0]));
  expectThrows<StateError>('empty program', () => runProgram([]));
  expectThrows<StateError>('dangling operand', () => runProgram([1]));
  expectThrows<StateError>('step limit',
      () => runSource('loop:\nJMP loop\nHALT', maxSteps: 1000));

  // maxSteps counts executed instructions, generously enough for real work.
  final ok = runSource('PUSH 3\nloop:\nDUP\nJZ end\nPUSH 1\nSUB\nJMP loop\n'
      'end:\nHALT', maxSteps: 100);
  check('bounded run finishes', ok.stack.length, 1);

  // Deeply recursive calls resolve in order.
  final deep = runSource('PUSH 0\nCALL a\nPRINT\nHALT\n'
      'a:\nPUSH 1\nADD\nCALL b\nRET\n'
      'b:\nPUSH 1\nADD\nRET');
  check('nested call arithmetic', deep.output.first, 2);

  // Labels may be referenced before or after their definition line.
  final flow = runSource('JMP over\nmid:\nPUSH 2\nPRINT\nJMP end\n'
      'over:\nPUSH 1\nPRINT\nJMP mid\nend:\nHALT');
  check('label ordering', '${flow.output}', '[1, 2]');
  if (failures > 0) exit(1);
  print('edge ok');
}
