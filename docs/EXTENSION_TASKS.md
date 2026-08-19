# Corpus extension — eight stacks, 160 tasks (corpus 100 → 260)

Approved 2026-08-19. Binding task list for the authoring fan-out. Every rule
in [TASK_AUTHORING.md](TASK_AUTHORING.md) still applies verbatim: 8 simple /
8 mid / 4 complex per stack, two weighted hidden-test groups (core 4.0, edge
2.0), the three security canaries last in `task.toml`, prompts that never
mention tests or scoring, and the dual gate (solution 1.00, starter ≤ 0.05).

The frozen 100-task corpus is **not** touched — the three completed/ongoing
rounds keep their comparability; new stacks extend future rounds only.

Directory: `tasks/<stack>/<tier>/<slug>/` with stack ∈ `typescript`,
`javascript`, `postgres`, `docs`, `bash`, `powershell`, `html-css`, `r`.
Id prefixes: `ts-`, `js-`, `pg-`, `doc-`, `sh-`, `ps-`, `web-`, `r-`.

Budgets by tier (unchanged): simple 300 s / $0.25, mid 720 s / $1.00,
complex 1800 s / $4.00.

---

## typescript (`ts-`) — the type system is part of the task

Oracles: hidden `node --test` suites over compiled output **plus** hidden
type-level assertion files (`@ts-expect-error` probes) that must pass
`npx tsc --noEmit --strict`. A solution that works at runtime but loosens
types fails. Toolchain: global TypeScript 7.0.2. No npm dependencies.

| Tier | Tasks |
|---|---|
| simple | typed event-map emitter · discriminated-union reducer with exhaustiveness · hand-rolled `DeepReadonly<T>` · type-guard suite (`is`/`asserts`) for a message union · **debug: seeded `any` leak breaks downstream narrowing** · template-literal route params · const-asserted config deriving unions · enum↔union utilities |
| mid | zod-subset schema validator with inferred output types · compile-time-checked state machine · mapped-type form validator · `Result<T,E>` combinator pipeline · **refactor: untyped JS module → strict TS, visible runtime tests preserved** · branded unit types with arithmetic guards · typed CSV parser inferring columns from a header tuple · token-typed dependency container |
| complex | type-safe SQL query-builder subset (result type follows selections) · overloaded caching decorators preserving generics · shared client/server RPC contract layer · **legacy: untyped codebase, 3 bugs that surface only under strict types, + feature** |

## javascript (`js-`) — language-core semantics (no overlap with the `node` stack)

Oracles: hidden `node --test` suites; several tasks assert engine semantics
(prototype chains, microtask ordering, cycles). Zero dependencies.

| Tier | Tasks |
|---|---|
| simple | **debug: closure-in-loop counter factory shares state** · prototype-based mixin composer · cycle-safe deep clone · lazy range iterator · **debug: promise chain swallows rejections (missing return)** · event emitter with once/off · curry with placeholders · property-descriptor audit utilities |
| mid | hand-rolled Promise (then/catch/all, thenable resolution, microtask order) · generator-based cooperative scheduler · Proxy observable with path subscriptions · structured serializer (cycles, Map, Set) · **refactor: callback pyramid → async/await, visible tests preserved** · WeakMap memoizer with TTL + injectable clock · tagged-template SQL escaper · glitch-free reactive signals |
| complex | async-iterator stream combinators with backpressure · virtual-DOM diff/patch over plain objects · stack-machine interpreter with closures · **legacy: event-driven cart, 3 bugs (listener leak, stale total, double-fire) + feature** |

## postgres (`pg-`) — schema, queries, integrity

Each trial provisions an isolated database (`createdb`/`dropdb` around the
oracle run). Hidden oracles are SQL assertion scripts run under
`psql -v ON_ERROR_STOP=1`: result-set equality, expected constraint
violations, and `EXPLAIN` plan-shape checks. **No timing assertions** —
they are not deterministic. Toolchain: PostgreSQL 16.

| Tier | Tasks |
|---|---|
| simple | multi-join revenue report · `GROUP BY`/`HAVING` cohort aggregates · **debug: missing FK admits orphan rows** · date/interval report with gap filling · idempotent `ON CONFLICT` upsert · `CHECK`/`UNIQUE` retrofit to spec · updatable view · `COALESCE`/`NULLIF` cleanup over dirty data |
| mid | window functions (running totals, per-group rank, dedup by recency) · recursive CTE over an org hierarchy · normalize a denormalized table (DDL + FK-safe backfill) · audit trigger capturing old/new row JSON · partial + expression indexes proven by `EXPLAIN` · materialized view with correct refresh semantics · row-level security for multi-tenancy · JSONB queries with a GIN index |
| complex | full schema design from a requirements doc, validated by scenario queries · PL/pgSQL workflow with transactional integrity · query rewrite: result-equality **and** plan-shape checks · **legacy: broken migration chain, 3 interacting defects + feature migration** |

## docs (`doc-`) — comprehension in, documents out

Workspaces hold multi-file source material; oracles are Python-stdlib
checkers validating structure, extracted facts, cross-document consistency
and citation integrity. **Stated limit:** v1 grades verifiable content and
structure, not prose quality (an LLM-rubric layer is the v2 upgrade).

| Tier | Tasks |
|---|---|
| simple | meeting notes → minutes with decisions table · invoices → totals CSV (arithmetic exact) · merge/dedupe contact lists · commit log → grouped CHANGELOG · CSV → markdown report with summary row · docs-folder front-matter index · fill a letter template from JSON (nothing invented) · anchored table of contents |
| mid | cross-reference 5 reports → discrepancy list (all seeded, no false positives) · tickets → FAQ with sourced answers · user stories → numbered spec with full traceability · rewrite to a lintable style guide · source comments → API reference covering every public symbol · four reports → rollup whose metrics table sums · contract → structured clause JSON · corpus → grounded glossary |
| complex | research brief with line-range citations that all resolve · policy set → compliance checklist covering every id once · schema + comments + samples → complete data dictionary · **legacy: contradictory doc set → corrected master + errata table** |

## bash (`sh-`) — runs under WSL for a faithful POSIX environment

Oracles: hidden bash assertion scripts (`["wsl","bash","oracle.sh"]` style,
path-converted like the dsh shim). Several tasks target the classic failure
modes: quoting, word-splitting, `pipefail`.

| Tier | Tasks |
|---|---|
| simple | log extractor pipeline · batch renamer safe for spaces/newlines · awk CSV summer · find-and-prune with dry-run · **debug: word-splitting mangles spaced filenames** · retry with exponential backoff · dotenv loader/validator · human-readable directory size report |
| mid | getopts parser with subcommands · parallel runner with concurrency cap · log rotation with lock discipline · **debug: subshell/pipefail loses exit codes** · hash-manifest incremental backup · envsubst-style templater · pidfile supervisor (start/stop/status) · **refactor: monolith → functions under `set -euo pipefail`** |
| complex | mini test framework with TAP output · deploy pipeline with atomic symlink swap + rollback · awk log analytics with sessionization · **legacy: deploy script, 3 bugs (quoting, race, swallowed errors) + feature** |

## powershell (`ps-`) — native Windows

Oracles: hidden `.ps1` assertion scripts, exit-code based, no Pester
dependency. All inputs are fixture files — never live system state.

| Tier | Tasks |
|---|---|
| simple | Import-Csv grouping report · file organizer honoring `-WhatIf` · culture-invariant string/date parsing · JSON config merger · **debug: single-item pipeline returns scalar where array expected** · try/catch/ErrorAction wrapper · hashtable counter report · text template expander |
| mid | advanced function (CmdletBinding, pipeline input, parameter sets) · module with manifest and exports · **debug: `$script:` scope bug drops accumulated state** · runspace/job parallel processor · idempotent installer with drift detection · log parser emitting objects into a grouped report · **refactor: flat script → documented module** · DPAPI credential handling, no plaintext at rest |
| complex | mini build system with hash-based incremental graph · REST client module (retry, pagination) against a bundled Node mock server · declarative file-state enforcer with drift report · **legacy: ops script, 3 bugs (`-eq` misuse, null propagation, culture-sensitive parsing) + feature** |

## html-css (`web-`) — markup, layout, accessibility

Oracles: Python-stdlib HTML parsing for structure/semantics/ARIA plus
stylesheet-text assertions (selectors, custom properties, media queries,
grid/flex declarations). **Stated limit:** no pixel rendering in v1 —
structure and declared behavior are graded, visual polish is not.

| Tier | Tasks |
|---|---|
| simple | semantic restructure of div soup · accessible form (labels, fieldsets, aria-describedby) · responsive card grid · CSS-only dropdown nav · **debug: specificity conflict hides live content** · data table with caption/scope · hero section from spec using custom properties · print stylesheet |
| mid | CSS-only accordion + tabs · grid dashboard matching an ASCII wireframe · dark mode via custom properties + `prefers-color-scheme` · **debug: stacking context traps a modal behind its overlay** · BEM refactor against a published class contract · `:invalid`/`:user-invalid` validation styling · fluid type scale with `clamp()` · skeletons with reduced-motion guard |
| complex | landing page from a written design spec · email-safe HTML newsletter (table layout, inline styles) · CSS-only component set with correct a11y semantics · **legacy: multi-page site, 3 layout bugs + a new page matching existing patterns** |

## r (`r-`) — base-R semantics and statistics

Oracles: hidden `Rscript` files using base-R `stopifnot()`. Zero packages,
seeded RNG, fully deterministic. Toolchain: R 4.x.

| Tier | Tasks |
|---|---|
| simple | recycling-safe vector utilities · factor releveling + ordered summary · data-frame cleaning with explicit NA policy · apply-family reshaping (no loops) · **debug: `drop=TRUE` collapses a one-column frame** · regmatches/gsub extraction · date arithmetic with business-month buckets · merge with `all.x` semantics |
| mid | base-R group-summarize to an exact contract · long↔wide reshape both ways, package-free · S3 class with print/summary/format · closure-based accumulator module · **debug: lazy-evaluation capture in lapply-generated functions (missing `force`)** · seeded vectorized Monte Carlo · **refactor: loop-heavy → vectorized, visible tests preserved** · formula wrapper around `lm` with tidy diagnostics |
| complex | composable base-R data verbs (select/filter/mutate/arrange/summarise) · bootstrap CI + permutation test, seeded and exact · S4 class system (validity, generics, show) · **legacy: 3-script pipeline, 3 bugs (factor→integer coercion, stringsAsFactors assumption, silent recycling) + feature** |
