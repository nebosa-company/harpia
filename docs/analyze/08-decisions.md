# 8. Decisions

Every non-obvious call made while building this layer, the alternative that was
rejected, and why. Grouped by the principle each one serves.

---

## A. Unmeasured is never a pass

The rule inherited from HarnessBench: *"a rubric that never ran scored
identically to a rubric that ran and found nothing wrong."* Nine places where it
is enforced, each of which would otherwise have defaulted to something
flattering.

| Situation | Rejected default | What happens instead |
|---|---|---|
| Neither accounting path reports usage | treat as 0 tokens | `Outcome::Malformed` |
| Task lacks the round's prompt variant | run the canonical prompt | task left unmeasured, count printed |
| Round never attempted a task | score 0.0 | `NaN` in the matrix, excluded everywhere |
| Item is constant across rounds | discrimination 0.0 | `None` — nothing to correlate |
| Fewer than 2 rounds | print an alpha anyway | `not computable`, with the reason |
| Oracle audit never run | omit the section | `never audited — run harpia audit` |
| No mutant could be generated for a task | count as caught | named as *unaudited, not clean* |
| Diff-based security check with no diff | pass | fail closed: `workspace diff not captured` |
| Content hash unknown on one side of a pair | assume same task | counted as *unverified*, printed |

## B. Representation

**Missing cells are `NaN`, not zero.** The single most consequential
representational decision in the layer. Rounds cover different corpora; a
cancelled round covers part of one. Reading "not attempted" as 0.0 would poison
every mean, correlation, interval and ranking downstream, and would make a
partial round look catastrophic rather than partial.

**Content hashing excludes `solution/`.** It never enters a trial sandbox, so
editing it cannot change what a round measured. Including it would drop valid
pairings for no gain.

**Trials record the content hash they ran against, not the task's current one.**
A later corpus edit must not retroactively make two rounds look comparable.

**`Fault` is a separate axis from `Outcome`.** What happened versus whose it
was. Merging them is how a provider 503 becomes a permanent line on a harness's
scorecard.

**Proxy columns hold only an independent *second* measurement.** When the proxy
is the primary path its numbers go in the ordinary telemetry columns. Copying
them into both would make disagreement trivially zero and inflate the
cross-checked count with trials that were only ever measured once.

## C. Statistics

**No stats dependency, ever.** Bootstrap, McNemar, Wilcoxon, Kendall tau,
Cronbach's alpha, ICC, Wilson intervals, the normal quantile and SHA-256 are all
in-tree with unit tests. A benchmark's numbers must not move because a
dependency bumped a minor version — and the decision of whether two rounds may
be compared least of all.

**One seeded PRNG for everything.** `harpia-core/src/rng.rs`. Two runs of the
same report produce identical numbers or "robustness" is a word with no
referent.

**A tie counts as a flip in rank stability.** A resample that fails to separate
two rounds has not reproduced an ordering that separated them. Index tie-breaks
counting as agreement is exactly how a one-task lead reads as settled — the test
`a_hairline_gap_is_not_stable` holds the line.

**Corrected item-total correlation, not raw.** The raw version contains the item
on both sides and inflates itself by roughly `1/√k`. Not cosmetic at this corpus
size.

**Alpha may go negative; it is not clamped.** A negative alpha is the honest
signal that items measure different things. Undefined (zero between-round
variance) returns `None` instead.

**Wilson intervals for every rate over a small denominator.** Mutation score,
invariance, infra rate. The normal approximation is wrong exactly where these
live.

**Alternative scoring rules are recomputed from oracle verdicts.** A stored
capability already contains the weighting under test. This is the reason
`round_oracles()` exists in the store.

**MDE at 80% power and α = 0.05, fixed rather than configurable.** So the number
means the same thing in every report. Power is computed against the *observed*
effect, which is the question a reader of a null result actually has.

## D. Oracle auditing

**Comments and string literals are never mutated.** A mutation inside a comment
behaves identically, the oracles correctly pass it, and the audit would record a
surviving mutant — slandering an oracle that did nothing wrong. This single
decision separates a meaningful mutation score from noise.

**`0` and `1` are not off-by-one candidates; floats are skipped.** Mutating
structural constants produces crashes, which everything catches and which prove
nothing. `2.5 → 2.6` is not an off-by-one.

**`drop-statement` only applies to `;` languages.** In an indentation-scoped
language, deleting the only statement in a block is a syntax error, and a syntax
error is not a mutant.

**Style oracles are excluded from audit verdicts.** A `static` check objecting
to a stray blank line is doing its job. Counting it as an oracle defect would
bury the behavioural failures that matter. The one place the audit deliberately
measures less than it could — stated, not hidden.

**CRLF is skipped for shebang files and scripts.** The interpreter genuinely
cares, so the "harmless" rewrite would not be harmless and would manufacture
false-fails.

**Re-auditing supersedes rather than accumulates.** A task fixed after a failed
audit should read as fixed, not be averaged against its own history.

## E. Contamination

**Containment, not Jaccard.** A 40-line task embedded in a 4000-line public file
scores near zero on Jaccard and near one on containment, and it is the second
number that should worry anyone. The asymmetry is asserted in a unit test so it
cannot be silently undone.

**Internal overlap is measured alongside external.** Two near-identical tasks
are one task counted twice, quietly doubling that item's weight in every mean.

## F. Gaming detection

**The workspace is snapshotted before the oracles run.** Hidden tests are
injected during grading; a snapshot taken afterwards attributes the oracle's own
files to the harness. This also silently fixed `diff_stat`, which had been
counting injected test files as harness edits.

**Diffs compare trimmed lines as sets.** Reindented code is not a new line;
a moved line is not an added one. Without this, any formatter the harness runs
lights up every detector at once.

**Suppression detection is a curated list of line-level markers.** Detecting
"a lint config was edited" fires on legitimate work; detecting "a line
containing `@pytest.mark.skip` was added" does not.

**Dependency names come from a heuristic, not five ecosystem parsers.** The
check raises a flag; it does not render a verdict, and five parsers to maintain
would be a poor trade.

## G. Guards and escape hatches

**The comparability guard has no `--allow-mismatch` flag.** It would be used,
and the first thing lost would be the property the guard exists to protect.
Mismatched pairings are counted and printed, never silently dropped.

**Unverified pairings are kept, not dropped.** Dropping them makes the tool
useless on every pre-v3 round — which is all three that exist. Treating them as
verified would be a lie. Counting them apart and printing the warning is the
only option that is both usable and true.

**Infra faults are separated but not removed by default.** The report prints
both the headline capability and the infra-excluded one. Excluding by default
lets a bad network afternoon improve a score; not separating lets it ruin one.
Printing both is the only version with no hidden choice.

**Fault classification is deliberately narrow** — seventeen specific
substrings. Over-matching would launder real harness failures into excused ones,
which is worse than the confusion it fixes.

## H. Deliberately not built

**Item Response Theory (2PL).** Would give difficulty and discrimination on a
latent scale plus a measurement-information curve. It needs far more subjects
than three rounds; adding it now would produce confident-looking parameters
estimated from nothing. Revisit at roughly ten rounds.

**Mechanical paraphrase generation.** A reframing transform measures sensitivity
to framing, not to wording. Shipping it as paraphrase would put a generated
number where an authored one belongs. The mechanism (`prompt_variants`,
`--prompt-variant`, unmeasured cells for tasks that lack a variant) is
implemented and empty — an honest empty slot.

**Alternative reference solutions per task.** The best remaining investment in
oracle validity, and not automatable: it is corpus authoring work.

**Human audit of sampled trial outcomes.** The only check that bounds the error
of every other check here, and the only one no code can perform.
