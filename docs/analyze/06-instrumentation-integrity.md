# 6. Instrumentation integrity — did the accounting actually get measured?

**Question.** Harpia exists partly because HarnessBench reported rounds with
requests but zero tokens, tokens but zero requests, and no cost at all. The fix
is not "be careful"; it is to make missing accounting a scored, visible defect
and to check the numbers against something.

**Code.** `harpia-core/src/metrics.rs` (`TelemetrySource`, `ProxyUsage`,
`Fault`), `harpia-runner/src/trial.rs`, `harpia-report/src/meta.rs`
(`integrity_of`). **Command.** `harpia robustness`.

## What is recorded per trial

| Column | Meaning |
|---|---|
| `telemetry_source` | `first-party` · `proxy` · `both` · `missing` |
| `proxy_*_tokens`, `proxy_requests` | the independent second count, when one exists |
| `fault` | `none` · `harness` · `infra` |
| `session_id` | which `harpia run` process produced the trial |

## What is reported per round

- **zero-token / zero-request / null-cost / malformed counts.** Four ways an
  accounting hole shows up, counted separately rather than summarised.
- **source distribution.** How many trials each accounting path measured.
  A round reading `missing 140` is a round whose usage numbers came from
  nowhere identifiable.
- **cross-checked count and disagreement.** Only trials with source `both` can
  be checked at all; for those, `|proxy − own| / max(proxy, own)`, mean and max.
- **cost reconciliation.** Harness-reported cost against the versioned price
  table, as MAPE over trials where both exist.
- **infra-fault count and rate**, with a Wilson interval, plus **capability
  recomputed with infra trials removed**.

## Decisions

**A trial where *neither* accounting path yields usage is `Malformed`.** Not
zero, not silently accepted. This is the proposal's §4.7 made executable, and
it is the reason `Outcome::Malformed` exists.

**`Malformed` now requires both paths to be silent.** Previously a zero
first-party request count alone condemned the trial. With a cross-check path
configured, a harness whose own log is empty but whose wire traffic was counted
is measured, not malformed — and its `telemetry_source` records which path
spoke.

**The proxy columns hold only an *independent second* measurement.** When the
proxy is the primary path (dsh), its numbers go in the normal telemetry columns
and the proxy columns stay empty. Copying them into both would make
disagreement trivially zero and inflate the cross-checked count with trials
that were only ever measured once. `cross_checked` counts source `both`, and
nothing else.

**Two counts that agree are the only evidence either is right.** This is why
`cross_check_path` and `cross_check_telemetry` exist on the manifest: any
harness can be given a second, independent accounting path, and the report will
compare them. It is declarative, so adding it to a harness is a manifest edit.

**`Fault` is separate from `Outcome`.** `Outcome` says what happened; `Fault`
says whose it was. Without the split a provider 503 and a harness that cannot
write a file both land as `Crashed` and both read as incapability — a bad
afternoon on the network becomes a permanent line on a harness's scorecard.

**Both capability numbers are printed when infra faults exist.** Excluding them
by default would let infrastructure trouble quietly improve a score; including
them silently lets it quietly ruin one. Printing headline *and*
`capability excluding infra faults` is the only version with no hidden choice.

**Cost is reconciled, not replaced.** Where a harness reports its own cost, that
number is kept and compared against the price table. A large MAPE is a finding —
about the price table, about effort-tier pricing, or about the harness's
arithmetic — and resolving it by overwriting one number with the other would
destroy the evidence.

## How to read it

```
perp-flash-r1   140 trials: zero-token 0  zero-request 0  null-cost 0  malformed 0
    sources: missing 140   cross-checked 0   disagreement mean n/a max n/a
    cost reconciled on 140 trials, MAPE 0.0%   infra faults 0 (0%)

dsh-flash-r1    140 trials: zero-token 0  zero-request 0  null-cost 140  malformed 0
    cost reconciled on 0 trials, MAPE n/a

cc-opus5-...     60 trials: zero-token 0  zero-request 0  null-cost 0  malformed 0
    cost reconciled on 60 trials, MAPE 160.9%
```

Three different states, all real:

- **perp** — complete, and its self-reported cost matches the price table
  exactly (MAPE 0.0%), which is expected when both derive from the same table.
- **dsh** — every token counted, **no cost on any of 140 trials**. This is
  precisely the HarnessBench defect resurfacing one column over, and it is now
  a printed number rather than a footnote.
- **cc-opus5** — cost reported on every trial, and it disagrees with the price
  table by **161%**. Either the table is wrong for this model/effort tier or the
  harness's `total_cost_usd` means something else. Unresolved, and visible.

`sources: missing 140` on all three rounds is honest: those rounds predate
source recording, and the column reads `missing` rather than guessing
`first-party`.

## Limits

- Cross-checking needs a manifest to declare a second path. None of the shipped
  manifests does yet, so `cross_checked` is zero everywhere — the machinery is
  proven by tests, not by a round.
- Infra-fault classification reads process output. A provider failure that
  surfaces as a clean non-zero exit with no diagnostic text is classified as a
  harness fault, and no substring list will fix that.
- MAPE over reported-vs-table cost cannot say *which* side is wrong. It says
  they disagree and by how much.
