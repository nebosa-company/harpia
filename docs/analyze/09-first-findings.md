# 9. First findings

**Run: 2026-08-19, against the three rounds in `harpia.db`.** Reproduce with:

```bash
harpia robustness --db harpia.db
```

These are the numbers the machinery produced the first time it was pointed at
the existing data. They are not flattering, which is the point — a
meta-evaluation that agrees with everything you already believed has not
measured anything.

Ordered by how much each one should change what gets reported.

---

## 1. Four fifths of the scored corpus separates nobody

```
100 items over 3 rounds: 21 live, 79 dead (78 ceiling, 0 floor), 2 negative
effective n = 21 (the n a confidence interval is entitled to)
```

Across the 100 tasks the rounds touched — 100 each for the two flash rounds, 60
for the cancelled Claude Code round — **78 were solved by every round that
attempted them**, and one more is constant for other reasons. Those items add
nothing to any ranking while narrowing every interval computed over them.
(Reliability and rank stability run on the 60 items all three rounds share.)

The honest denominator for a confidence interval on the current rounds is **21**,
not 100 — and certainly not the corpus's full 260.

**What to do.** The corpus needs harder items, not more items. The 78
ceiling tasks still have a role as a regression floor, but they should not carry
weight in a capability interval. Reporting `effective n` beside every headline
is the minimum; a difficulty-stratified capability number is the better fix.

## 2. Two tasks rank harnesses backwards

```
dart-s-anagram-grouper   r = -0.420
dart-s-phone-normalizer  r = -0.420
```

The rounds the rest of the corpus calls strong are the ones failing these two.
At three subjects a correlation of −0.42 is not conclusive, but negative
discrimination is far more often a defect in the task or its oracle than a
discovery about the harness. Both are worth reading before the next round.

## 3. The residual is bigger than the effect being reported

```
round 12% | task 4% | residual 84%
residual exceeds the round effect: the ranking is inside the noise
```

Only 12% of the score variance is attributable to which harness ran. 84% is
unexplained — interaction and noise. Combined with finding 4, this is the
strongest single caution against reading the leaderboard as settled.

## 4. Repeats do not agree, and one round is far worse than the other

```
perp-flash-r1  20 repeat tasks: flake 35%  ICC 0.381  within-sd 0.170  pass@1 0.733 pass@3 0.900
dsh-flash-r1   20 repeat tasks: flake 10%  ICC 0.684  within-sd 0.055  pass@1 0.867 pass@3 0.900
```

Seven of twenty repeat tasks flapped under Perpetum; two under dsh. An ICC of
0.381 means an attempt is close to a coin flip on the tasks that vary — and the
capability rounds are single-attempt.

Note the pass@1 / pass@3 gap: on the 20-task repeat subset both harnesses reach
0.900 given three attempts, from 0.733 and 0.867 at one. On that subset the
difference between them is largely *reliability*, not reach.

## 5. The top two rounds cannot be separated by this design

```
dsh-flash-r1 vs cc-opus5-high-r1: n 60
    diff +0.044 [-0.006, +0.106]  sd 0.225  MDE@80% 0.081  power 33.3%
    McNemar p 0.6250   UNDERPOWERED
```

The observed gap (0.044) is **half** the smallest gap this pairing could have
detected (0.081), at 33% power. `p = 0.6250` here means "not resolvable", not
"equivalent". The other two pairings are adequately powered (93% and 97%) and
their gaps do hold.

The claim "Claude Code + Opus 5 leads" is currently supported against Perpetum
and **not** supported against dsh.

## 6. The leader owes its position to one stack

```
without dart  ( 80 items left) leader dsh-flash-r1   LEADER CHANGES
```

Drop the twenty Dart tasks and the top of the table changes hands. Every other
stack and every tier leaves the leader intact. Bootstrap agrees this is a close
call: order preserved in 95% of resamples, with the top pair flipping 5% of the
time on a gap of 0.044.

## 7. Two accounting holes, both previously invisible

```
dsh-flash-r1    140 trials: null-cost 140   cost reconciled on 0 trials
cc-opus5-...     60 trials: cost reconciled on 60 trials, MAPE 160.9%
```

- **dsh recorded no cost on any of its 140 trials.** This is HarnessBench's
  zero-token defect resurfacing one column over — the exact failure Harpia was
  built to prevent, in a round Harpia itself ran.
- **Claude Code's self-reported cost disagrees with the price table by 161%.**
  Either the table is wrong for that model and effort tier, or `total_cost_usd`
  means something other than what the table computes. Unresolved.

All three rounds also read `sources: missing`, because they predate telemetry-
source recording. They are not wrong; they are unattributed, and now say so.

## 8. dsh's score is heavily budget-bound — and the bound trials scored high

```
dsh-flash-r1  timeouts 53  ceilings 0  budget-bound 38%  cap when bound 0.975
```

**38% of dsh's trials hit the wall clock**, and those trials still scored 0.975
capability. The work was being done correctly; the process was not exiting.
That is a harness-lifecycle fact being folded into a capability number.

This is the finding most likely to move the leaderboard: a `--budget-scale 2.0`
round for dsh would separate "cannot finish in budget" from "does not exit".

## 9. No comparison between the existing rounds is content-verified

```
paired 100 tasks (0 content-verified, 100 unverified, 0 dropped)
NOT a proven like-for-like corpus
```

The three rounds carry three different corpus SHAs (`f9e3e42`, `980f42d`,
`7e92aab`) and predate per-task content hashing, so sameness cannot be proven
either way. Every round from now on records it; these three never will.

## 10. The corpus has no canaries

```
260 tasks: 0 carry a canary, 0 of those unique
containment p50 0.088  p95 0.180  max 0.241
```

The design's contamination argument depends on every workspace carrying a unique
canary. **None of the 260 tasks declares one.** The field exists in `task.toml`
and is unset everywhere, so the claim cannot currently be made.

The overlap side is healthy: peak internal containment of 0.241 among Flutter
simple tasks is scaffolding overlap, not duplicate tasks. External overlap is
unmeasured until `harpia contamination --against <corpus>` is pointed at one.

## 11. One oracle accepts broken code (in the 8 tasks audited so far)

```
mutation score 0.933 [0.702, 0.988] (14/15 mutants caught)
invariance     1.000 [0.806, 1.000] (16/16 rewrites still pass)
  survived: py-s-word-freq (flip-le) — oracle accepts broken code
2 task(s) produced no mutant at all — unaudited, not clean
```

`py-s-word-freq`'s hidden tests do not distinguish `<=` from `<`. The fix is a
boundary case in the task's tests. Note the interval: at fifteen mutants the
true mutation score is anywhere from 0.70 to 0.99 — this is a pilot on the
python-simple tier, not a corpus-level result.

Invariance is perfect so far: no oracle rejected a semantically identical
rewrite.

---

## What this implies for the next round

1. **Run dsh at `--budget-scale 2.0`.** 38% timeouts at 0.975 capability makes
   this the highest-value single experiment available.
2. **Finish the Claude Code round.** 60 of 100 tasks, and the pairing against
   dsh is underpowered at that n.
3. **Audit the full corpus** (`harpia audit --jobs 4`), overnight. The pilot
   found a real defect in eight tasks.
4. **Add canaries** to all 260 tasks, or drop the contamination claim from the
   design until they exist.
5. **Resolve the Claude Code cost discrepancy**, and give dsh a cost path.
6. **Report `effective n` beside every capability figure**, and stop citing
   n = 100 for intervals that 21 items are carrying.

None of these are changes to the measurement machinery. They are what the
machinery is now saying to do.
