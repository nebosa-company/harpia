# Measuring the benchmark

**Status: implemented, v0.2** · 2026-08-19

Harpia grades harnesses. These documents are about the other half of the job:
grading Harpia. A benchmark that has never been measured is a benchmark whose
error bars are unknown, and a number with unknown error bars cannot support the
claim it is printed to support.

Everything described here is implemented, tested, and runnable from the CLI.
Each document states the question, the method with its formula, where the code
lives, the command that produces the number, and — most importantly — the
decisions that were made and what was rejected.

## The seven questions

| # | Question | Document | Command |
|---|---|---|---|
| 1 | Do the tasks still carry information? | [Item quality](01-item-quality.md) | `harpia robustness` |
| 2 | Does the same round twice give the same answer? | [Reproducibility](02-reproducibility.md) | `harpia robustness` |
| 3 | Does the leaderboard survive being poked? | [Ranking robustness](03-ranking-robustness.md) | `harpia robustness` |
| 4 | Are the oracles measuring the right thing? | [Oracle validity](04-oracle-validity.md) | `harpia audit` |
| 5 | Were the tasks ours, and did anyone cheat? | [Contamination and gaming](05-contamination-and-gaming.md) | `harpia contamination` |
| 6 | Did the accounting actually get measured? | [Instrumentation integrity](06-instrumentation-integrity.md) | `harpia robustness` |
| 7 | Were the two rounds even comparable? | [Comparability and power](07-comparability-and-power.md) | `harpia compare` |

Plus:

- **[Decisions](08-decisions.md)** — every non-obvious call, the alternative
  that was rejected, and why. Read this one if you read only one.
- **[First findings](09-first-findings.md)** — what the machinery said the
  first time it was pointed at the existing three rounds. It is not flattering,
  which is the point.

## Running it

```bash
harpia robustness --db harpia.db
```

One report, every read-only check: item analysis, reliability, rank stability,
leave-one-out, scoring-rule sensitivity, variance decomposition, repeat
agreement, paired power, instrumentation integrity, budget exposure, batch
effects, and whichever of the audit / drift / contamination sections have data.
`--json` for the machine-readable form, `--rounds a,b` to restrict it.

The three sections that need their own sweep, because they run code rather than
read the database:

```bash
harpia audit --tasks tasks --db harpia.db --jobs 4
```

```bash
harpia contamination --tasks tasks --db harpia.db --against ../public-corpora
```

```bash
harpia validate --tasks tasks --db harpia.db --record
```

`validate --record` is what makes drift measurable: each sweep is stored with
the toolchain it ran under, and `harpia drift` diffs the last two.

## The rule that ties it together

> An unmeasured factor propagates as **unavailable**, never as 1.0 and never
> as 0.

This is inherited from HarnessBench, where "a rubric that never ran scored
identically to a rubric that ran and found nothing wrong" was the failure mode.
Every section above prints *never audited* / *not computable* / *unverified*
rather than a default. Missing telemetry is an `Outcome::Malformed`, missing
prompt variants leave a cell unmeasured, an un-run oracle audit is `None`, and
a pairing whose sameness cannot be proven is counted apart from one that can.

## Where the code lives

| Layer | Crate | What it holds |
|---|---|---|
| Arithmetic | `harpia-core` | `stats`, `psychometrics`, `robustness`, `matrix`, `rng`, `hash` — no I/O, all unit-tested against hand-built cases |
| Storage | `harpia-store` | schema v3 columns and the `oracle_audit`, `corpus_check`, `contamination` tables; `meta.rs` holds the typed read paths |
| Execution | `harpia-runner` | `audit`, `contamination`, `content`, `toolchain`, plus fault classification and budget/wording knobs in `trial`/`round` |
| Detection | `harpia-oracle` | `security.rs`: the three canaries plus four gaming detectors |
| Prose | `harpia-report` | `meta.rs` builds and renders the whole report; `lib.rs` holds the guarded `compare` |

The split is deliberate: no meta-evaluation arithmetic touches the filesystem
or the database, so every claim in these documents is testable from a matrix
literal. `cargo test -p harpia-core` proves the maths without a corpus.
