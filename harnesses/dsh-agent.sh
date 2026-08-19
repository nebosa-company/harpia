#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Launch dsh (DeepSeek's harness) on one Harpia trial, inside WSL.
#
# Modeled on harness-bench/scripts/dsh-agent.sh. Everything runs Linux-side:
# a Windows-bound proxy on 127.0.0.1 is unreachable from WSL2's namespace, so
# the usage proxy is a stdlib Python relay started HERE, per trial, writing
# proxy-jsonl usage lines to a sandbox file the Rust runner reads afterward.
#
# Required env: DEEPSEEK_API_KEY.
# Optional env: DSH_REPO, DSH_VENV_PY, DSH_MODEL, DEEPSEEK_UPSTREAM.
set -euo pipefail

WORKSPACE="" PROMPT_FILE="" SESSION_ID=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --workspace)   WORKSPACE="$2"; shift 2 ;;
        --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
        --session-id)  SESSION_ID="$2"; shift 2 ;;
        *) echo "dsh-agent: unknown arg: $1" >&2; exit 2 ;;
    esac
done
[[ -n "$WORKSPACE" && -n "$PROMPT_FILE" && -n "$SESSION_ID" ]] || {
    echo "usage: dsh-agent.sh --workspace P --prompt-file P --session-id ID" >&2
    exit 2
}
[[ -n "${DEEPSEEK_API_KEY:-}" ]] || { echo "dsh-agent: DEEPSEEK_API_KEY is not set" >&2; exit 3; }

# Windows paths arrive as D:\... or D:/...; convert for WSL.
to_wsl() {
    local p="${1//\\//}"
    if [[ "$p" =~ ^([A-Za-z]):(/.*)$ ]]; then
        echo "/mnt/${BASH_REMATCH[1],,}${BASH_REMATCH[2]}"
    else
        echo "$p"
    fi
}
WORKSPACE="$(to_wsl "$WORKSPACE")"
PROMPT_FILE="$(to_wsl "$PROMPT_FILE")"
SANDBOX="$(dirname "$WORKSPACE")"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DSH_REPO="${DSH_REPO:-/mnt/d/repos/deepseek-harness}"
VENV_PY="${DSH_VENV_PY:-$HOME/dsh-bench-venv/bin/python}"
export DSH_MODEL="${DSH_MODEL:-deepseek-v4-flash}"
UPSTREAM="${DEEPSEEK_UPSTREAM:-https://api.deepseek.com}"

# Per-trial usage proxy in THIS network namespace.
USAGE_LOG="$SANDBOX/dsh-usage.jsonl"
PORT_FILE="$SANDBOX/dsh-proxy-port.txt"
: > "$USAGE_LOG"
rm -f "$PORT_FILE"
python3 "$SELF_DIR/dsh-usage-proxy.py" \
    --upstream "$UPSTREAM" --usage-log "$USAGE_LOG" --port-file "$PORT_FILE" \
    2>> "$SANDBOX/dsh-proxy.err.log" &
PROXY_PID=$!
trap 'kill "$PROXY_PID" 2>/dev/null || true' EXIT
for _ in $(seq 1 50); do
    [[ -s "$PORT_FILE" ]] && break
    sleep 0.1
done
[[ -s "$PORT_FILE" ]] || { echo "dsh-agent: proxy did not start" >&2; exit 4; }
export DEEPSEEK_BASE_URL="http://127.0.0.1:$(cat "$PORT_FILE")"
echo "dsh-agent: proxying through $DEEPSEEK_BASE_URL -> $UPSTREAM" >&2

# Session root beside the workspace, never inside it — the session log must
# not be graded as a task artifact.
SESSIONS="$SANDBOX/dsh-sessions"
mkdir -p "$SESSIONS"

PROMPT="$(cat "$PROMPT_FILE")"
[[ -n "${PROMPT// }" ]] || { echo "dsh-agent: prompt file is empty" >&2; exit 2; }

cd "$DSH_REPO"
"$VENV_PY" examples/jsonrpc-agent/minimal.py \
    --workspace "$WORKSPACE" \
    --session-root "$SESSIONS" \
    --session-id "$SESSION_ID" \
    "$PROMPT"
