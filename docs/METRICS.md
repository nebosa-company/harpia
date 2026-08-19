# What Harpia records, and what a report can therefore say

Written against the metric inventory of `perpetum.io/docs/build/comparisson.html`
— the class of cross-round report this database has to be able to feed.

Everything below is a column or a derivation, not a plan. Where a metric is
*not* collectable, that is stated rather than approximated.

## Where each report row comes from

| Report section | Harpia source |
|---|---|
| **Identity** — harness, harness version, model as configured, model on the wire, reasoning effort, request parameters, link, round date | `harness.harness_version` (probed from the harness's own `--version`, not Harpia's), `round.model`, `round.model_wire`, `round.effort`, `round.params`, `round.link_kind`, `round.started_epoch` |
| **Coverage** — tasks scored, not yet run, adapter failures | `count(trial)`, `round.corpus_size − count(trial)`, `trial.outcome IN ('crashed','malformed')` |
| **Outcome** — median task, spread (σ), security, oracle checks passed | derived from `oracle_result` per trial; `kind='security'` splits security from capability |
| **Distribution** — scored 1.0 / 0.7–1.0 / 0.3–0.7 / 0–0.3, ≥0.9, <0.5 | histogram over per-trial capability |
| **Work done** — tool calls, tool calls/task, failing tool results, turns, model calls, steps | `trial.tool_calls`, `trial.tool_errors`, `trial.turns`, `trial.requests`, `trial.steps`, and per-call rows in `tool_call` |
| **Speed** — wall clock, machine busy, longest pause, mean task, mean call latency | `round.started_epoch`/`finished_epoch` (elapsed) vs `sum(trial.wall_ms)` (busy); gaps between consecutive `trial.started_epoch`/`finished_epoch` give idle; `model_call.latency_ms` gives call latency |
| **Tokens** — input excl. cache, served from cache, cache hit, output, per-task rates, cache write | `trial.*_tokens`, and `model_call.*` for the per-call distribution |
| **Money** — charged, cost/task, cost per point of score | `trial.cost_usd` with `model_call.cost_is_shadow` distinguishing billed from imputed; `price` table for shadow pricing |
| **Every task, every round** | `trial × task`, joined on `task_id` across rounds |
| **By domain** | `task.stack` and `task.tier` (finer than the reference report's single class axis) |
| **Head to head, margin, leader** | paired per-task capability across two rounds |
| **The statistical view** | `harpia-core::stats` — seeded bootstrap CIs, exact McNemar, tie-corrected Wilcoxon, pass@k |
| **Pareto — where points are lost** | `oracle_result.kind` + `detail`, aggregated across trials |
| **When each round ran** | `round.started_epoch` / `finished_epoch` |

## Deliberately not collected

- **LLM-rubric process scores** (tool use / consistency / robustness, and the
  review-gate rows). HarnessBench grades these with a model. Harpia measures
  process through observable facts instead — outcome classes, tool error
  rate, refusals, stability across repeats — because a rubric that never ran
  scores identically to one that ran and found nothing wrong.
- **`combined = outcome × process × security`.** Harpia keeps capability,
  security and stability separate; collapsing them hides exactly the
  trade-off a harness bench exists to expose.

## Honest gaps in what a harness will tell us

These are recorded as absent, never as zero:

- **dsh reports no tool calls.** Its usage is captured on the wire, and the
  wire carries tokens, not tool invocations. `trial.tool_calls = 0` for a dsh
  round means *not observable*, and a report must say so rather than printing
  a zero next to Perpetum's 3,172.
- **Subscription links bill nothing.** `model_call.cost_is_shadow` marks an
  imputed price so a `$0` is never confused with a free run.
- **`model_call` is empty for harnesses that report only totals.** Claude
  Code aggregates usage into one final `result` event, so per-call latency
  is unavailable there — again absent, not zero.
