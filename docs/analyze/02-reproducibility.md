# 2. Reproducibility — does the same round twice give the same answer?

**Question.** If the identical (harness, model, effort) triple ran the identical
corpus again, how close would the number come back? Everything else in these
documents is conditional on this one having a good answer.

**Code.** `harpia-core/src/stats.rs` (`icc_1_1`, `variance_components`,
`pass_at_k`) and `harpia-report/src/meta.rs` (`repeats_of`, `session_effect`).
**Command.** `harpia robustness`.

## What is computed

### Flake rate, per round and per task

Over the stability subset — the tasks a round ran more than once — the share
whose attempts disagreed about solved / not solved. Reported with the task ids,
because *which* tasks flap is the actionable half:

```
perp-flash-r1  20 repeat tasks: flake 35%  ICC 0.381  within-sd 0.170
    flapping: dart-m-async-refactor, flutter-m-connectivity-banner, ...
```

A task that flaps for *every* harness is a corpus defect. A task that flaps for
one is a fact about that harness. Naming them is what lets the two be told
apart; a single composite stability score cannot.

### ICC(1,1) — test–retest reliability

One-way random-effects intraclass correlation over the repeat groups: the share
of total variance that lies *between* tasks rather than *between attempts of the
same task*. Unbalanced groups are handled with the standard `k0` correction, so
a task with two attempts and a task with three can sit in the same estimate.

Read it as: **ICC near 1** means repeats agree and the ranking rests on
something stable; **ICC near 0** means an attempt is a coin flip and any
ordering built from single attempts is an artefact of which coin came up.

### Within-task dispersion

Mean σ of the capability scores inside each repeat group. Complements ICC:
ICC is relative (between vs within), σ is absolute. A corpus of near-identical
tasks can post a poor ICC with tiny σ, and that combination is benign.

### pass@1 vs pass@k

The unbiased Chen et al. estimator, already in the codebase. `pass@1` is what a
capability round measures; `pass@k` is what the same harness achieves given `k`
attempts. The gap between them is retry headroom, and it is large exactly where
flake is large.

### Variance decomposition

A two-way decomposition of the rounds × tasks score matrix into three
components:

| Component | Meaning |
|---|---|
| **round** | how much of the spread is the harness/model under test |
| **task** | how much is task difficulty — expected, and not a problem |
| **residual** | interaction plus noise: the part no factor explains |

Negative component estimates clamp to zero, as is conventional. The line the
report draws:

> residual exceeds the round effect: the ranking is inside the noise

If the unexplained part is larger than the effect being reported, the
leaderboard is being read off a quantity smaller than its own error term.

### Batch effects

Every trial records the `session_id` of the `harpia run` process that produced
it. A round assembled across several sittings — resumed after a crash, finished
the next day — is then testable: mean capability per session, and the largest
gap between them. A round whose second session scores materially differently is
not one measurement; it is two, and the report says so instead of assuming
homogeneity.

## Decisions

**Repeats stay on a stratified subset.** Three attempts on all 260 tasks would
triple the cost of every round for information the 20-task subset already
carries. Inherited from the proposal, and unchanged: variance lives in repeats,
but it does not need every task to be visible.

**Session effects use every trial, not just attempt 1.** The question is whether
work done in one sitting scored differently from work done in another, and
repeats are part of that work. Restricting to attempt 1 would blind the check to
exactly the resumed-round case it exists for.

**A timeout is nobody's fault.** `Fault::None`, and it stays in the capability
denominator. It is a budget outcome the benchmark deliberately measures — see
[budget exposure](03-ranking-robustness.md#budget-sensitivity). Only crashes and
unparseable accounting get a blame assignment.

**Infra faults are separated but not silently removed.** `Fault::Infra` is
recorded per trial and the report prints both the headline capability and
`capability excluding infra faults`. Removing them by default would let a bad
network afternoon quietly improve a harness's score; not separating them at all
lets it quietly ruin one. Printing both is the only version with no hidden
choice.

**Fault classification is deliberately narrow.** Seventeen specific substrings
(`connection refused`, `503 service unavailable`, `no space left on device`, …).
Over-matching would launder real harness failures into excused ones, which is
worse than the confusion it fixes. The list is in `harpia-runner/src/trial.rs`
and every entry has to earn its place.

## Limits

- ICC over three attempts on twenty tasks is a wide estimate. It is reported
  because a wide estimate of reproducibility beats none, not because it is
  precise.
- The true test–retest measurement — the *same* round label run twice
  end-to-end — is not yet in the database. The machinery reads it the moment it
  exists (two rounds, same design key, compared as a pair); nothing more needs
  building.
- Variance decomposition assumes one observation per cell and no missing data,
  so it runs on complete cases. With three rounds it estimates a round component
  from two degrees of freedom, which is thin. It is still the number that says
  whether residual dominates.
