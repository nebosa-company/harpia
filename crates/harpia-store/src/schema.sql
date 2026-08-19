-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Harpia schema v1. Idempotent: CREATE IF NOT EXISTS only.

CREATE TABLE IF NOT EXISTS harness (
    id          TEXT PRIMARY KEY,          -- e.g. 'perpetum', 'dsh', 'claude-code'
    version     TEXT NOT NULL,
    manifest    TEXT NOT NULL              -- the adapter TOML, verbatim, for provenance
);

CREATE TABLE IF NOT EXISTS round (
    id          INTEGER PRIMARY KEY,
    label       TEXT NOT NULL UNIQUE,      -- e.g. 'perpetum-deepseek-flash-r1'
    harness_id  TEXT NOT NULL REFERENCES harness(id),
    model       TEXT NOT NULL,
    effort      TEXT,                      -- e.g. 'high'
    tasks_sha   TEXT NOT NULL,             -- git SHA of the task corpus
    started_at  TEXT NOT NULL,
    finished_at TEXT
);

CREATE TABLE IF NOT EXISTS task (
    id          TEXT PRIMARY KEY,          -- e.g. 'rust-mid-lru-cache'
    stack       TEXT NOT NULL,
    tier        TEXT NOT NULL,
    title       TEXT NOT NULL,
    spec        TEXT NOT NULL              -- task.toml, verbatim
);

CREATE TABLE IF NOT EXISTS trial (
    id          INTEGER PRIMARY KEY,
    round_id    INTEGER NOT NULL REFERENCES round(id),
    task_id     TEXT NOT NULL REFERENCES task(id),
    attempt     INTEGER NOT NULL,          -- 1..n repeats for stability
    outcome     TEXT NOT NULL,             -- finished|timeout|cost-ceiling|crashed|malformed
    wall_ms     INTEGER NOT NULL,
    input_tokens        INTEGER NOT NULL DEFAULT 0,
    output_tokens       INTEGER NOT NULL DEFAULT 0,
    cache_read_tokens   INTEGER NOT NULL DEFAULT 0,
    cache_write_tokens  INTEGER NOT NULL DEFAULT 0,
    requests    INTEGER NOT NULL DEFAULT 0,
    turns       INTEGER NOT NULL DEFAULT 0,
    tool_calls  INTEGER NOT NULL DEFAULT 0,
    tool_errors INTEGER NOT NULL DEFAULT 0,
    cost_usd    REAL,
    diff_stat   TEXT,                      -- '+120 -8' final workspace diff
    UNIQUE (round_id, task_id, attempt)
);

CREATE TABLE IF NOT EXISTS oracle_result (
    trial_id    INTEGER NOT NULL REFERENCES trial(id),
    oracle_idx  INTEGER NOT NULL,
    kind        TEXT NOT NULL,
    passed      INTEGER NOT NULL,
    weight      REAL NOT NULL DEFAULT 1.0,
    detail      TEXT,
    PRIMARY KEY (trial_id, oracle_idx)
);

CREATE TABLE IF NOT EXISTS tool_call (
    trial_id    INTEGER NOT NULL REFERENCES trial(id),
    seq         INTEGER NOT NULL,
    name        TEXT NOT NULL,
    ok          INTEGER NOT NULL,
    PRIMARY KEY (trial_id, seq)
);

CREATE TABLE IF NOT EXISTS price (
    model       TEXT PRIMARY KEY,
    input_per_mtok  REAL NOT NULL,
    output_per_mtok REAL NOT NULL,
    cache_read_per_mtok REAL NOT NULL DEFAULT 0,
    cache_write_per_mtok REAL NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_trial_round ON trial(round_id);
CREATE INDEX IF NOT EXISTS idx_trial_task ON trial(task_id);

-- ---- schema v2: the grain cross-round reports need ----
-- Fresh databases get these columns from the ALTERs in migrate(); the table
-- below is new, so it is declared here.

CREATE TABLE IF NOT EXISTS model_call (
    trial_id    INTEGER NOT NULL REFERENCES trial(id),
    seq         INTEGER NOT NULL,
    at          INTEGER,                   -- epoch seconds, as the harness logged it
    step        TEXT,                      -- harness-internal step id
    role        TEXT,                      -- coder | verifier | chat | ...
    link        TEXT,                      -- which configured link carried it
    model       TEXT,                      -- model as named on this call
    input_tokens        INTEGER NOT NULL DEFAULT 0,
    cache_read_tokens   INTEGER NOT NULL DEFAULT 0,
    cache_write_tokens  INTEGER NOT NULL DEFAULT 0,
    output_tokens       INTEGER NOT NULL DEFAULT 0,
    latency_ms  INTEGER,
    cost_usd    REAL,
    cost_is_shadow INTEGER NOT NULL DEFAULT 0,
    ok          INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (trial_id, seq)
);

CREATE INDEX IF NOT EXISTS idx_model_call_trial ON model_call(trial_id);

-- ---- schema v3: measuring the benchmark, not just with it ----
-- Everything below exists so a claim about a harness can be audited: what the
-- oracles actually accept, whether the corpus still validates, whether two
-- rounds were run over the same bytes, and whether the tasks were ours.

-- Oracle validity. A mutation that survives means the oracle accepts a wrong
-- solution; a semantics-preserving rewrite that fails means it rejects a right
-- one. Both are defects of the benchmark, recorded per task and dated.
CREATE TABLE IF NOT EXISTS oracle_audit (
    id          INTEGER PRIMARY KEY,
    at_epoch    INTEGER NOT NULL,
    task_id     TEXT NOT NULL,
    content_sha TEXT,                      -- task content when audited
    kind        TEXT NOT NULL,             -- 'mutation' | 'metamorphic'
    operator    TEXT NOT NULL,             -- which transform was applied
    target      TEXT NOT NULL,             -- file it was applied to
    expected    TEXT NOT NULL,             -- 'fail' | 'pass'
    observed    REAL NOT NULL,             -- capability the oracles gave
    passed      INTEGER NOT NULL,          -- oracle behaved as it must
    detail      TEXT
);

CREATE INDEX IF NOT EXISTS idx_oracle_audit_task ON oracle_audit(task_id);

-- Corpus validation over time. `harpia validate` writes one row per task per
-- run, so toolchain drift shows up as a task that used to validate and no
-- longer does, instead of as a mysteriously harder benchmark.
CREATE TABLE IF NOT EXISTS corpus_check (
    id                  INTEGER PRIMARY KEY,
    at_epoch            INTEGER NOT NULL,
    task_id             TEXT NOT NULL,
    content_sha         TEXT,
    solution_capability REAL NOT NULL,
    starter_capability  REAL NOT NULL,
    ok                  INTEGER NOT NULL,
    toolchain           TEXT                -- JSON: probed tool versions
);

CREATE INDEX IF NOT EXISTS idx_corpus_check_task ON corpus_check(task_id);

-- Contamination surface per task: its canary, whether that canary is unique
-- across the corpus, and the closest match found against an external corpus.
CREATE TABLE IF NOT EXISTS contamination (
    task_id        TEXT PRIMARY KEY,
    at_epoch       INTEGER NOT NULL,
    canary         TEXT,
    canary_unique  INTEGER,
    max_similarity REAL,                   -- 0..1 shingle overlap
    nearest_source TEXT,
    corpus_label   TEXT                    -- what it was compared against
);
