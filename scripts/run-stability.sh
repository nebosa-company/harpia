#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Stability pass: attempts 2-3 on the fixed stratified 20-task subset.
# Resume-safe: attempt 1 is already recorded from the capability pass and is
# skipped; re-running this script never duplicates work.
# Usage: run-stability.sh <harness> <model> <label> [harpia.exe path]
set -euo pipefail
HARNESS="$1"; MODEL="$2"; LABEL="$3"
BIN="${4:-target/debug/harpia.exe}"
cd "$(dirname "$0")/.."
while read -r task; do
    [[ -n "$task" ]] || continue
    "$BIN" run --harness "$HARNESS" --model "$MODEL" --label "$LABEL" \
        --tasks tasks --harnesses harnesses --db harpia.db --runs runs \
        --attempts 3 --jobs 2 --oracle-timeout 600 --filter "$task"
done < scripts/stability-subset.txt
