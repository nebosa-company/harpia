# 3. Ranking robustness — does the leaderboard survive being poked?

**Question.** The ordering was produced by one aggregation of one corpus under
one set of budgets. How much of it is a property of the harnesses, and how much
of the choices its author made?

**Code.** `harpia-core/src/robustness.rs`. **Command.** `harpia robustness`.

Six independent pokes. Each one re-derives the ordering a different defensible
way and reports whether it survived.

## 1. Bootstrap rank stability

Resample the tasks with replacement, recompute every round's mean, rebuild the
leaderboard, repeat 4000 times (seeded, so the number is reproducible). Report:

- **order preserved** — share of resamples reproducing the full ordering,
- **top-1 share** — share in which each round came first,
- **Kendall tau** against the full-corpus ordering: median and 5th percentile,
- **per-pair flip rate**, worst pair first.

This is the direct answer to *would another corpus of the same kind have ranked
these the same way*, and it is the single most convincing robustness number
available without running more rounds.

**A tie counts as a flip.** A resample that fails to separate two rounds has not
reproduced an ordering that separated them. Letting an index tie-break count as
agreement is precisely how a one-task lead reads as settled — the unit test
`a_hairline_gap_is_not_stable` exists to hold that line.

## 2. Leave-one-group-out

Recompute the leaderboard with each **stack**, each **tier**, and each **family**
removed in turn. Report the reduced leaderboard, its tau against the full one,
and — the line that matters — whether the leader changed.

A benchmark whose verdict depends on one stack is that stack's benchmark,
whatever its title says. Thirteen stacks make this cheap and decisive.

## 3. Single-item influence (jackknife)

Drop one task at a time and measure the change in the **top-two gap**. Sorted by
absolute effect, with a flag when removing that one task alone changes the
winner. One task able to flip a leaderboard is a finding about the corpus, not
about the harnesses.

## 4. Scoring-rule sensitivity

The stored capability is a weighted share of oracles passed. Three alternatives
are recomputed **from the stored oracle verdicts** — never from the stored score,
which already contains the weighting under test:

| Rule | Definition |
|---|---|
| `uniform-weights` | every oracle counts once, weights discarded |
| `strict-all-or-nothing` | 1.0 only if every non-security oracle passed |
| `per-stack-normalised` | mean of per-stack means, so a 20-task stack does not outvote a 3-task one |

For each: the leaderboard, its Kendall tau against the reference, and whether
the ordering held. If the ranking only survives one weighting, the weighting is
the result.

## 5. Budget sensitivity

Two halves.

**Passive** — every round reports its budget exposure: how many trials ended at
a wall-clock or cost ceiling, the share, and — the diagnostic — the **mean
capability of the trials that hit one**. A round that is 38% budget-bound is
partly a measurement of the ceiling. If those bound trials scored *high*, the
harness was doing correct work and simply never exited, which is a lifecycle
fact rather than a capability one.

**Active** — `harpia run --budget-scale 2.0` multiplies every task's wall-clock
and cost ceiling. Running the same harness at 1.0 and 2.0 turns budget
sensitivity into an ordinary paired comparison of two rounds. The scale is
recorded on the round, so the report can tell the arms apart.

## 6. Wording, order and concurrency

Three more knobs, each recorded on the round so a pair of rounds differing in
exactly one of them is an experiment rather than a confound:

- `--prompt-variant k` selects an alternative wording from the task's
  `prompt_variants`. **A task that does not define variant *k* is left
  unmeasured** — never quietly run with the canonical prompt, which would file a
  measurement of wording 0 under wording *k*. The count is printed at the end of
  the round.
- `--order-seed N` shuffles the work list deterministically, so an order effect
  can be tested instead of assumed absent.
- `--jobs N` was already recorded; two rounds differing only in it measure
  whether contention pushes trials into timeouts and out of capability.

## Decisions

**Resampling is seeded and the seed is a parameter.** Two runs of the same
report must produce the same numbers or "robustness" is a word with no
referent. One `Rng` (`harpia-core/src/rng.rs`) backs every bootstrap, shuffle
and resample in the codebase.

**Rank stability runs on complete-case items only.** A resample that draws a
task one round never attempted would compare means over different task sets.
The count of items actually used is printed beside the result.

**Leave-one-out reports the leader, not a p-value.** The question — *does the
verdict depend on this group* — is answered by whether the verdict changes. A
significance test on a subset of a corpus that is itself the population invites
a precision that is not there.

**Alternative rules are recomputed from oracle rows.** This is why
`round_oracles()` exists in the store. Deriving `strict` from a stored weighted
score is impossible, and deriving it approximately would be worse than not
doing it.

**Prompt-form transformations are not shipped as paraphrases.** A mechanical
reframing measures sensitivity to framing, not to wording; genuine lexical
paraphrase has to be authored per task. The mechanism (`prompt_variants` in
`task.toml`, `--prompt-variant` on the round, unmeasured cells for tasks that
lack it) is implemented and empty — an honest empty slot rather than a
generated one dressed up as the real thing.

## How to read it

```
bootstrap over 60 items x 4000 resamples: order preserved 95%
  led in 95% of resamples: cc-opus5-high-r1
  led in 5% of resamples: dsh-flash-r1
most fragile pair: cc-opus5-high-r1 over dsh-flash-r1 (gap 0.044) flips 5% of the time

leave-one-stack-out:
  without dart  ( 80 items left) leader dsh-flash-r1   LEADER CHANGES
```

The first block says the top of the table is 95% stable to task resampling —
respectable but not settled. The second says the leader owes its position to
the Dart tasks: remove that one stack and it changes hands. Both are facts about
the corpus that a single capability mean cannot express.

## Limits

- Bootstrap over tasks treats the corpus as a sample from a population of
  similar tasks. That population is hypothetical. The number answers "another
  corpus like this one", not "all agentic coding work".
- Leave-one-out is one group at a time. Simultaneous removal of two stacks is
  not explored; with thirteen stacks the pairwise space is large and the
  single-group result has been decisive enough so far.
- Budget, wording, order and concurrency sensitivity are all *implemented* as
  round knobs, but each needs a second round actually run to produce a number.
  Nothing about them is estimated in the meantime.
