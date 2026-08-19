/// Integer stack machine and assembler.

/// Result of a program run: the final stack (bottom first) and PRINT output.
class VmResult {
  final List<int> stack;
  final List<int> output;

  VmResult(this.stack, this.output);
}

/// Assembles source text into bytecode.
List<int> assemble(String source) => throw UnimplementedError();

/// Executes bytecode until HALT.
VmResult runProgram(List<int> code, {int maxSteps = 1000000}) =>
    throw UnimplementedError();

/// Assembles and runs in one step.
VmResult runSource(String source, {int maxSteps = 1000000}) =>
    throw UnimplementedError();
