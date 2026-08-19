# 1. Item quality — do the tasks still carry information?

**Question.** A round's headline number is a mean over 260 items. That mean is
only as informative as the items underneath it. Which of them are still doing
work, and how much of a reported score is signal rather than noise?

**Code.** `harpia-core/src/psychometrics.rs`, on the score matrix built in
`harpia-report/src/meta.rs`. **Command.** `harpia robustness`.

## What is computed

### Item difficulty, `p`

The mean score of one task across the rounds that attempted it. Low is hard.
Reported beside `solve_rate` (the share of rounds that cleared *every*
non-security oracle), because a task can have middling difficulty and a zero
solve rate — partial credit and pass/fail are different questions.

### Dead, ceiling and floor items

An item whose score has zero variance across rounds ranks nobody. It still
enters the mean, still enters the denominator of every confidence interval, and
therefore *narrows* the interval while adding no evidence — the exact opposite
of what a confidence interval is supposed to do. Three counts are reported:

- **ceiling** — every round scored 1.0,
- **floor** — every round scored 0.0,
- **dead** — zero variance for any reason (a superset of the two).

### Effective n

`live_items = n_items − dead_items`. This is the number a claim is entitled to
cite. Reporting *n = 260* when 200 of those items separate nobody is not a
rounding error; it is the difference between a defensible interval and a
decorative one.

```rust
impl ItemAnalysis {
    pub fn effective_n(&self) -> usize { self.live_items }
}
```

### Discrimination — corrected item-total correlation

For each item, the Pearson correlation between that item's scores and the mean
of **all other** items, across rounds. Positive means the item ranks harnesses
the way the corpus as a whole does. Zero means it is noise. **Negative means it
ranks them backwards** — the harnesses the rest of the corpus calls strong are
the ones failing it, which is a defect in the task or its oracle far more often
than it is a discovery about the harness.

The correlation is *corrected*: the item is excluded from the total it is
compared against. An uncorrected item-total correlation contains the item on
both sides and inflates itself, and at 260 items the inflation is roughly
`1/√k` — not cosmetic at this size.

### Reliability — Cronbach's alpha, split-half, SEM

- **alpha** over the complete-case matrix (items every round attempted). With
  0/1 entries this is KR-20. It answers: what share of the between-round
  variance in total score is consistent across items?
- **split-half**, odd/even items, Spearman–Brown corrected — a second estimate
  that does not assume equal item variances.
- **SEM** = `sd_total · √(1 − alpha)`. This is the error bar a *single* round
  score carries. Any claimed gap smaller than a couple of SEMs is inside the
  measurement error of the instrument, whatever the p-value says.

## Decisions

**Missing cells are `NaN`, never zero.** Rounds cover different corpora and a
cancelled round covers part of one. `ScoreMatrix` holds missing measurements as
`f64::NAN` and every consumer filters them explicitly. Reading "not attempted"
as 0.0 would make a partial round look catastrophically bad and would poison
every mean, correlation and interval downstream. This is the single most
important representational decision in the whole layer.

**Reliability is computed on complete cases only, and says so.** Pairwise
deletion would let alpha be assembled from different subsets of rounds per
item — a number with no single interpretation. The report prints how many items
survived (`complete_items`) beside the number.

**A constant item has `discrimination: None`, not 0.0.** Returning zero would
read as "measured, and found uncorrelated". `None` reads as "there is nothing
here to correlate", which is the truth. The same rule appears everywhere in
this layer.

**Alpha is allowed to go negative and is not clamped.** A negative alpha is the
honest signal that the items measure different things; clamping it to zero
would hide exactly the diagnosis the number exists to deliver. (Undefined —
zero between-round variance in total score — returns `None` instead.)

**One subject means no reliability.** With a single round every item looks
constant. The report says `not computable (needs >= 2 rounds over shared
items)` rather than showing a flattering 260 dead items as if it were a finding
about the corpus.

## How to read it

```
100 items over 3 rounds: 21 live, 79 dead (78 ceiling, 0 floor), 2 negative
effective n = 21 (the n a confidence interval is entitled to)
reliability: alpha 0.896  split-half 0.982  sd(total) 0.083  SEM 0.027
```

- **79 dead, 78 at the ceiling** — four fifths of that corpus slice is solved by
  everyone and separates nobody.
- **effective n = 21** — the honest denominator.
- **alpha 0.896** is high, but note what it is high *about*: consistency among
  the 21 items that vary.
- **SEM 0.027** — two round scores inside ~0.05 of each other are not
  distinguishable by this instrument.

## Limits

- Discrimination and reliability need rounds as their subjects, so they sharpen
  as more rounds land. At three rounds they are indicative, not settled; the
  report prints `n_subjects` beside them so the reader can discount
  accordingly.
- Classical test theory assumes items measure one latent trait. "Agentic coding
  ability" plainly is not one trait, which is part of why alpha is reported
  next to the per-stack cuts rather than on its own.
- Item Response Theory (2PL) would give difficulty and discrimination on a
  proper latent scale and a measurement-information curve. It needs far more
  subjects than three rounds. Deliberately not implemented yet — see
  [decisions](08-decisions.md).
