#!/usr/bin/env bash
# Launch dsh (DeepSeek's harness) on one Harpia trial, inside WSL.
# Modeled on harness-bench/scripts/dsh-agent.sh: the jsonrpc-agent SDK
# example is the working non-interactive entry; the CLI's headless profile
# needs a POSIX PTY the bench cannot give it.
#
# Required env:
#   DEEPSEEK_API_KEY   real key (requests go via DEEPSEEK_BASE_URL)
#   DEEPSEEK_BASE_URL  Harpia usage proxy URL (wire telemetry capture)
# Optional env:
#   DSH_REPO           default /mnt/d/repos/deepseek-harness
#   DSH_VENV_PY        default $DSH_REPO/.venv/bin/python
#   DSH_MODEL          default deepseek-v4-flash
set -euo pipefail

WORKSPACE="" PROMPT_FILE="" SESSION_ID=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --workspace)   WORKSPACE="$2"; shift 2 ;;
        --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
        --session-id)  SESSION_ID="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done
[[ -n "$WORKSPACE" && -n "$PROMPT_FILE" && -n "$SESSION_ID" ]] || {
    echo "usage: dsh-agent.sh --workspace P --prompt-file P --session-id ID" >&2
    exit 2
}

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

DSH_REPO="${DSH_REPO:-/mnt/d/repos/deepseek-harness}"
VENV_PY="${DSH_VENV_PY:-$DSH_REPO/.venv/bin/python}"
PROMPT="$(cat "$PROMPT_FILE")"
# Session root beside the workspace, never inside it — the session log must
# not be graded as a task artifact.
SESSIONS="${WORKSPACE%/}-dsh-sessions"
mkdir -p "$SESSIONS"

export DSH_MODEL="${DSH_MODEL:-deepseek-v4-flash}"
cd "$DSH_REPO"
exec "$VENV_PY" examples/jsonrpc-agent/minimal.py \
    --workspace "$WORKSPACE" \
    --session-root "$SESSIONS" \
    --session-id "$SESSION_ID" \
    "$PROMPT"
