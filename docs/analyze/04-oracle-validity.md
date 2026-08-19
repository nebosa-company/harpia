# 4. Oracle validity — are the oracles measuring the right thing?

**Question.** `harpia validate` proves a task *can* be passed and *can* be
failed. It says nothing about whether the oracle accepts wrong code or rejects
right code. In a code benchmark that is the largest hidden error source, and it
is fully automatable, because every task ships a reference solution.

**Code.** `harpia-runner/src/audit.rs`. **Command.** `harpia audit`.

## The two questions

### Mutation — does the oracle notice broken code?

Break the reference solution in a small, semantic way and re-run the oracles.
**They must fail.** A surviving mutant means the oracle accepts a wrong
solution: every harness scoring 1.0 on that task may have written the same bug,
and the benchmark would call it solved.

Seven operators, each applied at the first matching site so the audit is
deterministic:

| Operator | Change |
|---|---|
| `flip-le` / `flip-ge` / `flip-eq` | `<=`→`<`, `>=`→`>`, `==`→`!=` |
| `swap-and-or` | `&&`→`\|\|` |
| `off-by-one` | first integer literal ≥ 2, incremented |
| `negate-bool` | first `true`→`false` |
| `drop-statement` | delete the first standalone statement inside a block |

**Mutation score** = mutants caught / mutants generated, with a Wilson interval.

### Metamorphic — does the oracle reject correct code?

Rewrite the reference solution *without changing what it does* and re-run the
oracles. **They must still pass.** A failure is an oracle rejecting a correct
solution, which shows up in a round as capability the harness never actually
lost.

| Operator | Change |
|---|---|
| `trailing-comment` | append a comment in the file's own comment syntax |
| `blank-lines` | double every newline |
| `crlf` | convert line endings to CRLF |

**Invariance** = rewrites still passing / rewrites tried, with a Wilson
interval.

## Decisions

**Comments and string literals are never mutated.** `replace_first_code` scans
per line, cuts at the comment marker, and tracks quote state with escape
handling. A mutation inside a comment produces a file that behaves identically,
the oracles correctly pass it, and the audit would record a surviving mutant —
slandering an oracle that did nothing wrong. This is the difference between a
mutation score that means something and one that is noise.

**`0` and `1` are not off-by-one candidates, and floats are skipped entirely.**
Zero and one are usually structural (a zero index, a unit step) and mutating
them tends to produce a crash rather than a wrong answer — a crash is caught by
everything and proves nothing. `2.5 → 3.5` or `2.6` is not an off-by-one either,
so a digit on either side of a decimal point is left alone.

**`drop-statement` requires a statement terminator.** In an indentation-scoped
language, deleting the only statement in a block is a syntax error, and a
syntax error is not a mutant. The operator applies to `;` languages only and
skips declarations and `return` lines, whose removal is usually a compile error
rather than a behaviour change.

**Style oracles are excluded from the audit verdict.** A `static` check that
objects to a stray blank line is doing its job; counting that as an oracle
defect would bury the behavioural failures that matter. Only build, hidden-test
and probe oracles decide an audit outcome. This carve-out is the one place
where the audit deliberately measures less than it could, and it is stated
rather than hidden.

**CRLF is skipped for scripts and shebang files.** A shell interpreter genuinely
cares about the line ending, so the "harmless" rewrite would not be harmless.
Applying it anyway would manufacture false-fails and understate invariance.

**A task with no mutants is reported as unaudited, not as clean.** Some
reference solutions have no site any operator matches. Those tasks contribute
nothing to the ratio — and the report names them:

```
2 task(s) produced no mutant at all — unaudited, not clean: py-s-dict-flatten, py-s-mutable-default
```

This is the [README](README.md)'s central rule applied to the audit itself:
unmeasured propagates as unavailable, never as a pass.

**Re-auditing supersedes rather than accumulates.** `oracle_audits(latest=true)`
keeps one row per (task, kind, operator, target) via `MAX(id)`. A task fixed
after a failed audit should show as fixed, not be averaged against its own
history.

## How to read it

```
8 tasks audited
mutation score 0.933 [0.702, 0.988] (14/15 mutants caught)
invariance     1.000 [0.806, 1.000] (16/16 rewrites still pass)
  survived: py-s-word-freq (flip-le) — oracle accepts broken code
```

One surviving mutant is one task whose hidden tests do not distinguish `<=`
from `<`. The fix is a test case at the boundary, in the task — not a change to
the audit. Note the Wilson intervals: at fifteen mutants the score is anywhere
from 0.70 to 0.99, which is why the interval is printed and not just the point.

## Cost

An audit compiles and tests each task roughly ten times. Three controls:
`--filter` for a stack or tier, `--stride N` for every Nth task, and `--jobs N`
for parallelism. `--dry-run` prints without recording.

A full 260-task sweep is a long job and is meant to be: it is a corpus-level
number that changes only when the corpus does, not something to run per round.

## Limits

- Text-level operators cannot express every meaningful defect. An oracle can
  still be too weak in a way no operator reaches, and the mutation score is an
  upper bound on detection by *these* operators.
- Mutants are applied to the largest code file in `solution/` only. A task whose
  behaviour is spread across several files gets its oracles audited against one
  of them.
- Alternative-implementation testing — a second, independently written solution
  per task, checking that the oracle accepts a different but valid approach —
  is not implemented. It cannot be automated; it is corpus authoring work, and
  it remains the best next investment in oracle validity.
- Human audit of a stratified sample of real trial outcomes is likewise not
  automatable and not done. It is the only check that bounds the error of every
  other check here.
