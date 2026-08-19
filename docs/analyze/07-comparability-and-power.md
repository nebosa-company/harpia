# 7. Comparability and power — were the two rounds even comparable?

**Question.** A paired comparison assumes the pairs are pairs. And a
non-significant result assumes the design could have detected the effect. Both
assumptions were previously unchecked.

**Code.** `harpia-report/src/lib.rs` (`compare`), `harpia-runner/src/content.rs`,
`harpia-core/src/stats.rs` (`mde_paired`, `power_paired`),
`harpia-runner/src/toolchain.rs`. **Commands.** `harpia compare`, `harpia drift`.

## The comparability guard

### The defect it fixes

`compare()` paired two rounds by `task_id` and nothing else. A task id is a
name, and a name can be reused. Between two rounds a task's workspace or its
hidden tests may have been edited — and comparing the two halves of that edit is
not a paired design, it is two different tasks wearing one label. The three
rounds in the database were run at three different corpus SHAs
(`f9e3e42`, `980f42d`, `7e92aab`), so this was not a hypothetical.

### The fix: per-task content hashing

`content_sha` is a SHA-256 (first 16 hex chars) over everything a trial can see
or be graded by:

- `task.toml`,
- every file under `workspace/`,
- every file under `oracles/`.

Files are sorted by path, and each is fed in as `path \0 length bytes`, so
directory-iteration order cannot change the hash and a rename is a different
task. Path separators are normalised to `/` so a Windows and a Linux run of the
same corpus agree.

**`solution/` is deliberately excluded.** It never enters a trial sandbox, so
editing a reference solution cannot change what a round measured; including it
would drop pairings that are perfectly valid.

The hash is recorded twice: on the task row (what it is now) and on **each
trial** (what that trial actually ran against). Pairing reads the trial's copy,
so a later corpus edit cannot retroactively make two rounds look comparable.

### Three outcomes, counted separately

| Outcome | Meaning | Effect |
|---|---|---|
| **verified** | both rounds recorded the same content hash | paired |
| **unverified** | at least one round predates hashing | paired, and flagged |
| **mismatch** | both hashes known and different | **dropped** from every statistic |

```
paired  100 tasks (0 content-verified, 100 unverified)  |  dropped 0 on content mismatch
        NOT a proven like-for-like corpus; see the unverified/dropped counts
```

**Why unverified pairings are kept.** Dropping them would make the tool useless
on every round recorded before v3 — including all three that exist. Silently
treating them as verified would be a lie. Counting them apart and printing the
warning is the only option that is both usable and true.

## Power

Three numbers beside every comparison:

- **sd(diff)** — spread of the paired per-task differences,
- **MDE@80%** = `(z₀.₉₇₅ + z₀.₈) · sd / √n` — the smallest difference this
  pairing could have detected,
- **achieved power** = `Φ(|d|·√n / sd − z₀.₉₇₅)` — power against the difference
  actually observed.

Plus a bootstrap CI on the paired mean difference, and the flag:

```
diff +0.044 [-0.006, +0.106]  sd 0.225  MDE@80% 0.081  power 33.3%   UNDERPOWERED
```

**A result under the MDE is not evidence of similarity.** It is evidence of a
small *n*. Without this line, `p = 0.6250` reads as "these harnesses are
equivalent"; with it, the honest reading is "this pairing cannot resolve a gap
this size."

## Toolchain drift

Every stack is graded by running its real toolchain. When the toolchain moves —
a Rust release that tightens a lint, a Node bump that changes `node:test` output
— task difficulty moves with it, and without a record the benchmark reports that
as harnesses getting worse.

- `harpia run` probes eleven tools at round start and stores the versions as
  JSON on the round.
- `harpia validate --record` writes one `corpus_check` row per task per sweep,
  with the toolchain and the task's content hash.
- `harpia drift` diffs the last two sweeps: tasks that stopped validating,
  tasks that started, tasks whose content changed, and every toolchain version
  that moved.

`validate` also prints the **starter margin** — how far each task's untouched
starter sits below the 0.05 floor — and flags tasks within a third of it. A task
at 0.049 passes the gate and is one flaky assertion away from being
non-discriminative; seeing that before it happens is cheaper than diagnosing it
afterwards.

## Decisions

**SHA-256 is implemented in-tree.** ~100 lines in `harpia-core/src/hash.rs` with
known-answer tests. The decision of whether two rounds may be compared must not
change because a dependency bumped a minor version. It matches the crate's
existing stance on statistics: *"a benchmark must not drift with a stats
crate."*

**Sixteen hex characters, not sixty-four.** 64 bits of content addressing is
ample for a corpus of a few hundred tasks and fits in report output.

**The guard is on by default with no opt-out flag.** A `--allow-mismatch`
escape hatch would be used, and the first thing lost would be the property the
guard exists to protect. Mismatched tasks are reported, not silently dropped —
the count is printed on every comparison.

**MDE uses 80% power and α = 0.05.** Conventional, and stated rather than
configurable, so the number means the same thing in every report.

**Power is computed on the *observed* effect, not a hypothesised one.** It
answers "how much power did this comparison have against what it actually
found", which is the question a reader of a non-significant result has.

## Limits

- Content hashing can only protect rounds recorded under v3 or later. The three
  existing rounds are permanently unverifiable, and the report will keep saying
  so.
- The corpus SHA is still recorded and printed, and still useful as provenance —
  but it is no longer what decides comparability.
- Drift needs two recorded sweeps. Until `validate --record` has run twice, the
  section says so instead of implying stability.
