#!/usr/bin/env bash
# Deploy an artifact tree and record the result.
set -u
export LC_ALL=C

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SELF_DIR/lib/log.sh"
. "$SELF_DIR/lib/config.sh"
. "$SELF_DIR/lib/verify.sh"
. "$SELF_DIR/lib/state.sh"

usage() {
    echo "usage: deploy.sh [--dry-run] deploy --id ID --src DIR --dest DIR [--state DIR] [--verify CMD]" >&2
    echo "       deploy.sh history [--state DIR] [--limit N]" >&2
}

load_config "$SELF_DIR/config/app.conf"

DRYRUN=0
ACTION=""
ID=""
SRC=""
DEST=""
STATE="$STATE_DIR"
VERIFY="$VERIFY_CMD"
LIMIT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRYRUN=1; shift ;;
        --id)      [ $# -ge 2 ] || { usage; exit 2; }; ID="$2"; shift 2 ;;
        --src)     [ $# -ge 2 ] || { usage; exit 2; }; SRC="$2"; shift 2 ;;
        --dest)    [ $# -ge 2 ] || { usage; exit 2; }; DEST="$2"; shift 2 ;;
        --state)   [ $# -ge 2 ] || { usage; exit 2; }; STATE="$2"; shift 2 ;;
        --verify)  [ $# -ge 2 ] || { usage; exit 2; }; VERIFY="$2"; shift 2 ;;
        --limit)   [ $# -ge 2 ] || { usage; exit 2; }; LIMIT="$2"; shift 2 ;;
        -*)        usage; exit 2 ;;
        *)         [ -z "$ACTION" ] || { usage; exit 2; }; ACTION="$1"; shift ;;
    esac
done

case "$ACTION" in
    deploy)
        if [ -z "$ID" ] || [ -z "$SRC" ] || [ -z "$DEST" ]; then
            usage
            exit 2
        fi
        if [ ! -d "$SRC" ]; then
            log_err "no such directory: $SRC"
            exit 1
        fi
        SRC="${SRC%/}"

        files=()
        while IFS= read -r -d '' f; do
            files+=("${f#"$SRC"/}")
        done < <(find "$SRC" -type f -print0 | sort -z)

        if [ "$DRYRUN" -eq 1 ]; then
            for rel in ${files[@]+"${files[@]}"}; do
                printf 'DRY: copy %s\n' "$rel"
            done
            if [ -n "$VERIFY" ]; then
                printf 'DRY: verify\n'
            fi
            printf 'DRY: record %s\n' "$ID"
            exit 0
        fi

        mkdir -p -- "$DEST" || exit 1
        count=0
        for rel in ${files[@]+"${files[@]}"}; do
            mkdir -p -- "$DEST/$(dirname -- "$rel")" || exit 1
            cp -- "$SRC/$rel" "$DEST/$rel" || exit 1
            count=$((count + 1))
        done

        mkdir -p -- "$STATE" || exit 1

        if [ -n "$VERIFY" ]; then
            if ! run_verify "$DEST" "$VERIFY" "$STATE/verify.log"; then
                log_err "verify failed"
                exit 5
            fi
        fi

        record_deploy "$STATE" "$ID" "$count" || exit 1
        log_info "deployed: $ID ($count files)"
        exit 0
        ;;
    history)
        if [ -n "$LIMIT" ]; then
            case "$LIMIT" in
                ''|*[!0-9]*) usage; exit 2 ;;
            esac
            [ "$LIMIT" -ge 1 ] || { usage; exit 2; }
        fi
        [ -f "$STATE/history.tsv" ] || exit 0
        if [ -n "$LIMIT" ]; then
            cut -f1 "$STATE/history.tsv" | tac | head -n "$LIMIT"
        else
            cut -f1 "$STATE/history.tsv" | tac
        fi
        exit 0
        ;;
    *)
        usage
        exit 2
        ;;
esac
