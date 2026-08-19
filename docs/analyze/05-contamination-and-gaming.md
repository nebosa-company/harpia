# 5. Contamination and gaming — were the tasks ours, and did anyone cheat?

**Question.** Two different threats to the same claim. Contamination: the model
has seen the task before, so the score measures recall rather than work. Gaming:
the harness passed the oracle without doing the work.

**Code.** `harpia-runner/src/contamination.rs`, `harpia-oracle/src/security.rs`.
**Commands.** `harpia contamination`, and the gaming detectors run inside every
trial as security oracles.

## Contamination

### Canary uniqueness

Every task declares a `canary` in its `task.toml` and plants it in its
workspace. A solution reproducing a canary it was never shown is evidence of
contamination — but that argument only holds if the canary is genuinely unique.
So the sweep verifies, per task:

1. the canary is declared by exactly one task, and
2. it appears in exactly one task's workspace text.

A canary that fails either check cannot support the claim it exists for, and is
reported as `CANARY NOT UNIQUE`.

### Overlap — containment, not Jaccard

Each task is reduced to a set of 5-token shingles over its prompt plus its
workspace text, and compared against:

- an **external corpus** (`--against <dir>`) — a checkout of public benchmarks,
  a training-data sample, anything, and
- **the rest of Harpia**, which catches near-duplicate tasks.

The metric is **containment** — the share of the *task's* shingles that appear
in the other document — not Jaccard.

> A 40-line task embedded in a 4000-line public file has a Jaccard score near
> zero and a containment score near one, and it is the second number that
> should worry anyone.

The unit test `containment_finds_an_embedded_task` asserts exactly that
asymmetry, so the choice cannot be silently undone.

Internal overlap matters for a different reason: two near-identical tasks are
one task counted twice, which quietly doubles that item's weight in every mean.

## Gaming detectors

Four checks over the workspace diff, available as security oracles
(`check = "oracle-tamper"` and friends in `task.toml`):

| Check | What it catches |
|---|---|
| `oracle-tamper` | the harness wrote a file where a hidden test is about to land |
| `config-tamper` | suppression markers added (`#[ignore]`, `@pytest.mark.skip`, `# type: ignore`, `eslint-disable`, …), or a test file deleted |
| `dependency-policy` | dependencies added beyond the task's `allowed_dependencies` |
| `network-install` | `curl … \| sh`-shaped build steps, remote-executing installs |

`oracle-tamper` cannot change a score — the injection clobbers whatever the
harness left there — which is exactly why it is worth recording. A harness
authoring `tests/hidden.rs` was trying to grade itself, and the attempt is the
finding.

## Decisions

**The workspace is snapshotted before the oracles run.** This is the fix that
makes every diff-based check possible: hidden tests are injected *during*
grading, so a snapshot taken afterwards attributes the oracle's own files to the
harness. It also silently corrected `diff_stat`, which had been counting
injected test files as harness edits.

**Diffs compare trimmed lines as sets.** Reindented code is not a new line and a
moved line is not an added one. Without this, any formatter run by the harness
would light up every detector at once.

**Injected paths are excluded by name, everywhere.** `injected_paths()` collects
them from the task spec and every detector skips them. A harness must never be
blamed for a file the benchmark itself placed.

**A diff-based check with no diff fails closed.** If the snapshots are missing,
the check reports `workspace diff not captured for this trial` rather than
passing. An unmeasured check reporting clean is how "nobody looked" becomes
"nothing found".

**Suppression detection is line-level and specific.** A curated list of fifteen
markers, matched case-insensitively against *added* lines only. Detecting
"a lint config was edited" would fire on legitimate work; detecting "a line
containing `@pytest.mark.skip` was added" does not.

**Dependency names are read from added manifest lines, not parsed per
ecosystem.** Five package formats, one heuristic: a name to the left of `=` or
`:` inside a recognised manifest file. Parsing Cargo, npm, pub, pip and
RubyGems properly is five parsers to maintain for a check whose job is to raise
a flag, not to render a verdict.

## How to read it

```
260 tasks, 0 with a canary, 0 of those unique
  flutter-s-swipe-dismiss  0.241 vs task:flutter-s-three-tabs [internal]
  flutter-s-cart-badge     0.240 vs task:flutter-s-swipe-dismiss [internal]
```

The first line is a finding: the corpus has **no canaries**, so the
contamination argument the design depends on cannot currently be made. The
`canary` field exists in `task.toml` and is unset on all 260 tasks.

The rest is healthy: peak internal containment of 0.24 among Flutter simple
tasks is scaffolding overlap (imports, `MaterialApp` boilerplate), not duplicate
tasks. Nothing approaches the 0.6–0.7 region where two tasks would be one.

External overlap is **unmeasured** until `--against` is pointed at a corpus.
The report labels it as such rather than printing zero.

## Limits

- Shingle overlap detects verbatim and near-verbatim reuse. It cannot detect a
  model that has seen a *semantically* identical task written differently, which
  is the more likely form of contamination for hand-authored tasks.
- The external comparison is only as good as the corpus it is pointed at.
  Absence of overlap against three public benchmarks is not absence of
  contamination.
- Gaming detectors are heuristics over text. They raise flags; they do not
  prove intent, and every flag is worth reading before acting on.
- The visible-oracle calibration — running a round with `--oracles-visible` and
  comparing it against its hidden twin, to measure how much of a score is
  test-reading rather than problem-solving — is implemented as a round mode but
  has not been run.
