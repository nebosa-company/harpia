#!/usr/bin/env bash
# Deploy an artifact tree and record the result.

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SELF_DIR/lib/log.sh"
. "$SELF_DIR/lib/config.sh"
. "$SELF_DIR/lib/verify.sh"
. "$SELF_DIR/lib/state.sh"

usage() {
    echo "usage: deploy.sh deploy --id ID --src DIR --dest DIR [--state DIR] [--verify CMD]" >&2
    echo "       deploy.sh history [--state DIR] [--limit N]" >&2
}

load_config "$SELF_DIR/config/app.conf"

ACTION=""
ID=""
SRC=""
DEST=""
STATE="$STATE_DIR"
VERIFY="$VERIFY_CMD"
LIMIT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --id)     ID="${2-}"; shift; shift ;;
        --src)    SRC="${2-}"; shift; shift ;;
        --dest)   DEST="${2-}"; shift; shift ;;
        --state)  STATE="${2-}"; shift; shift ;;
        --verify) VERIFY="${2-}"; shift; shift ;;
        --limit)  LIMIT="${2-}"; shift; shift ;;
        -*)       usage; exit 2 ;;
        *)        ACTION="$1"; shift ;;
    esac
done

if [ "$ACTION" != "deploy" ]; then
    usage
    exit 2
fi

if [ -z "$ID" ] || [ -z "$SRC" ] || [ -z "$DEST" ]; then
    usage
    exit 2
fi

if [ ! -d "$SRC" ]; then
    log_err "no such directory: $SRC"
    exit 1
fi

mkdir -p "$DEST"
mkdir -p "$STATE"

count=0
for f in $(find $SRC -type f); do
    rel=${f#$SRC/}
    mkdir -p $DEST/$(dirname $rel)
    cp $f $DEST/$rel
    count=$((count + 1))
done

if [ -n "$VERIFY" ]; then
    run_verify "$DEST" "$VERIFY" "$STATE/verify.log"
    if [ $? -ne 0 ]; then
        log_err "verify failed"
        exit 5
    fi
fi

record_deploy "$STATE" "$ID" "$count"

log_info "deployed: $ID ($count files)"
exit 0
