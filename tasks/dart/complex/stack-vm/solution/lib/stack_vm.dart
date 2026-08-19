/// Integer stack machine and assembler.

/// Result of a program run: the final stack (bottom first) and PRINT output.
class VmResult {
  final List<int> stack;
  final List<int> output;

  VmResult(this.stack, this.output);
}

const Map<String, int> _opcodes = {
  'HALT': 0,
  'PUSH': 1,
  'ADD': 2,
  'SUB': 3,
  'MUL': 4,
  'DIV': 5,
  'MOD': 6,
  'NEG': 7,
  'DUP': 8,
  'DROP': 9,
  'SWAP': 10,
  'OVER': 11,
  'LOAD': 12,
  'STORE': 13,
  'JMP': 14,
  'JZ': 15,
  'CALL': 16,
  'RET': 17,
  'PRINT': 18,
};

const Set<String> _takesOperand = {
  'PUSH',
  'LOAD',
  'STORE',
  'JMP',
  'JZ',
  'CALL',
};

const Set<String> _labelOperand = {'JMP', 'JZ', 'CALL'};

final RegExp _labelName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
final RegExp _whitespace = RegExp(r'\s+');

class _Instr {
  final String mnemonic;
  final String? operand;
  final int line;

  _Instr(this.mnemonic, this.operand, this.line);
}

/// Assembles source text into bytecode.
List<int> assemble(String source) {
  final labels = <String, int>{};
  final instructions = <_Instr>[];
  var address = 0;
  final lines = source.split('\n');
  for (var n = 0; n < lines.length; n++) {
    var line = lines[n];
    final comment = line.indexOf(';');
    if (comment >= 0) line = line.substring(0, comment);
    line = line.trim();
    if (line.isEmpty) continue;
    if (line.endsWith(':')) {
      final name = line.substring(0, line.length - 1).trim();
      if (!_labelName.hasMatch(name)) {
        throw FormatException('bad label on line ${n + 1}');
      }
      if (labels.containsKey(name)) {
        throw FormatException('duplicate label $name on line ${n + 1}');
      }
      labels[name] = address;
      continue;
    }
    final parts = line.split(_whitespace);
    final mnemonic = parts[0].toUpperCase();
    if (!_opcodes.containsKey(mnemonic)) {
      throw FormatException('unknown mnemonic ${parts[0]} on line ${n + 1}');
    }
    if (_takesOperand.contains(mnemonic)) {
      if (parts.length != 2) {
        throw FormatException(
            '$mnemonic takes exactly one operand (line ${n + 1})');
      }
      instructions.add(_Instr(mnemonic, parts[1], n + 1));
      address += 2;
    } else {
      if (parts.length != 1) {
        throw FormatException('$mnemonic takes no operand (line ${n + 1})');
      }
      instructions.add(_Instr(mnemonic, null, n + 1));
      address += 1;
    }
  }
  final code = <int>[];
  for (final instr in instructions) {
    code.add(_opcodes[instr.mnemonic]!);
    final operand = instr.operand;
    if (operand == null) continue;
    if (_labelOperand.contains(instr.mnemonic)) {
      final target = labels[operand];
      if (target != null) {
        code.add(target);
      } else {
        final n = int.tryParse(operand);
        if (n == null) {
          throw FormatException(
              'undefined label $operand (line ${instr.line})');
        }
        code.add(n);
      }
    } else {
      final n = int.tryParse(operand);
      if (n == null) {
        throw FormatException('bad operand $operand (line ${instr.line})');
      }
      if ((instr.mnemonic == 'LOAD' || instr.mnemonic == 'STORE') && n < 0) {
        throw FormatException(
            'negative slot for ${instr.mnemonic} (line ${instr.line})');
      }
      code.add(n);
    }
  }
  return code;
}

/// Executes bytecode until HALT.
VmResult runProgram(List<int> code, {int maxSteps = 1000000}) {
  final stack = <int>[];
  final calls = <int>[];
  final slots = <int, int>{};
  final output = <int>[];
  var pc = 0;
  var steps = 0;

  int pop() {
    if (stack.isEmpty) throw StateError('stack underflow');
    return stack.removeLast();
  }

  while (true) {
    if (steps++ >= maxSteps) throw StateError('step limit exceeded');
    if (pc < 0 || pc >= code.length) {
      throw StateError('program counter out of range: $pc');
    }
    final op = code[pc++];
    int operand() {
      if (pc >= code.length) throw StateError('missing operand');
      return code[pc++];
    }

    switch (op) {
      case 0: // HALT
        return VmResult(stack, output);
      case 1: // PUSH
        stack.add(operand());
      case 2: // ADD
        {
          final b = pop();
          final a = pop();
          stack.add(a + b);
        }
      case 3: // SUB
        {
          final b = pop();
          final a = pop();
          stack.add(a - b);
        }
      case 4: // MUL
        {
          final b = pop();
          final a = pop();
          stack.add(a * b);
        }
      case 5: // DIV
        {
          final b = pop();
          final a = pop();
          if (b == 0) throw StateError('division by zero');
          stack.add(a ~/ b);
        }
      case 6: // MOD
        {
          final b = pop();
          final a = pop();
          if (b == 0) throw StateError('modulo by zero');
          stack.add(a - (a ~/ b) * b);
        }
      case 7: // NEG
        stack.add(-pop());
      case 8: // DUP
        {
          final v = pop();
          stack
            ..add(v)
            ..add(v);
        }
      case 9: // DROP
        pop();
      case 10: // SWAP
        {
          final b = pop();
          final a = pop();
          stack
            ..add(b)
            ..add(a);
        }
      case 11: // OVER
        {
          if (stack.length < 2) throw StateError('stack underflow');
          stack.add(stack[stack.length - 2]);
        }
      case 12: // LOAD
        {
          final slot = operand();
          if (slot < 0) throw StateError('negative slot');
          stack.add(slots[slot] ?? 0);
        }
      case 13: // STORE
        {
          final slot = operand();
          if (slot < 0) throw StateError('negative slot');
          slots[slot] = pop();
        }
      case 14: // JMP
        pc = operand();
      case 15: // JZ
        {
          final target = operand();
          if (pop() == 0) pc = target;
        }
      case 16: // CALL
        {
          final target = operand();
          calls.add(pc);
          pc = target;
        }
      case 17: // RET
        {
          if (calls.isEmpty) throw StateError('RET without CALL');
          pc = calls.removeLast();
        }
      case 18: // PRINT
        output.add(pop());
      default:
        throw StateError('unknown opcode $op');
    }
  }
}

/// Assembles and runs in one step.
VmResult runSource(String source, {int maxSteps = 1000000}) =>
    runProgram(assemble(source), maxSteps: maxSteps);
