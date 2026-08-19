# Harpia

A benchmark for **agentic coding harnesses**, not just for models.

The premise comes from a measurement that kept repeating: the same model,
`deepseek-v4-flash`, scored 0.628 under one harness and ~0.776 under another.
The harness was worth more than a model generation — and no benchmark was
measuring it. Harpia makes that comparison a first-class, statistically
defensible number, and then measures itself to see whether the number holds up.

## What one run is

A **round** is one `(harness, model, effort)` triple over the frozen task
corpus. A **trial** is one attempt at one task: fresh sandbox, harness runs
unattended, hidden oracles run after it exits, everything lands in SQLite.
Rounds are resumable — a killed round continues from the database and never
re-runs a finished trial.

```bash
harpia run --harness perpetum --model deepseek-v4-flash --label perp-r1 --jobs 4
harpia report --label perp-r1
harpia compare --a perp-r1 --b dsh-r1
```

## The corpus

260 tasks across 13 stacks — Rust, Dart, Flutter, Node, Python, TypeScript,
JavaScript, PostgreSQL, Bash, PowerShell, R, HTML/CSS, and technical docs — in
three tiers, balanced across four families: build, debug, refactor, and legacy
(a seeded mid-size codebase with interacting defects plus a feature request).

Every task ships a starter `workspace/`, hidden `oracles/` injected only after
the harness exits, and a reference `solution/` used for validation and never
shipped into a sandbox. All 260 pass the dual gate: reference solution scores
1.00, untouched starter scores ≤ 0.05.

```bash
harpia validate --tasks tasks --record
```

## Adding a harness

A harness is a TOML manifest, not a code change:

```toml
id        = "claude-code"
command   = ["claude", "-p", "{prompt}", "--model", "{model}",
             "--output-format", "stream-json"]
telemetry = "claude-stream-json"
```

Four telemetry parsers ship (`perpetum-journal`, `claude-stream-json`,
`proxy-jsonl`, `generic-jsonl`). Anything with a headless CLI and parseable
usage output is a manifest plus, at worst, one new parser arm. Manifests
support `${VAR:-default}` so a checkout runs unmodified here and needs one
environment variable elsewhere.

## Measuring the benchmark

A benchmark that has never been measured has unknown error bars, and a number
with unknown error bars cannot support the claim it is printed to support.

```bash
harpia robustness --db harpia.db
```

One report: item quality and reliability (how many tasks still separate
anyone), bootstrap rank stability, leave-one-stack-out, scoring-rule
sensitivity, repeat agreement and ICC, variance decomposition, paired power and
minimum detectable effect, instrumentation integrity, budget exposure, and
batch effects. Three further sweeps run code rather than read rows:

```bash
harpia audit          # break each reference solution; the oracles must notice
harpia contamination  # canary uniqueness and shingle containment
harpia drift          # what changed between the last two validation sweeps
```

One rule holds throughout: **an unmeasured factor propagates as unavailable,
never as a pass.** Missing telemetry is a recorded defect, an un-run audit says
so, and a comparison whose corpus cannot be proven identical is counted apart
from one that can.

The design, the decision log, and what the machinery said the first time it was
pointed at real rounds are in [`docs/analyze/`](docs/analyze/README.md).

## Layout

```
harpia-core     task/oracle/telemetry types · scoring · statistics · psychometrics · robustness
harpia-store    SQLite: harness, round, task, trial, oracle_result, tool_call, model_call, audit
harpia-harness  adapter trait + TOML manifests + telemetry parsers
harpia-oracle   build / hidden-test / static / security / gaming-detector runners
harpia-runner   sandbox lifecycle, worker pool, process-tree kill, resume, corpus auditing
harpia-report   scorecard, paired comparison, meta-evaluation
harpia-cli      harpia run | validate | report | compare | robustness | audit | contamination | drift
```

Cargo workspace, no async runtime — the hot path is child processes, so a sized
`std::thread` pool keeps the binary small and the scheduling deterministic.
Storage is `rusqlite` with bundled SQLite in WAL mode, every write
transactional. The statistics are dependency-free and unit-tested against
hand-built cases: a benchmark's numbers must not move because a crate did.

```bash
cargo test --workspace
```
