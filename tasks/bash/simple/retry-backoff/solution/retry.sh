#!/usr/bin/env bash
# Retry a flaky command with exponential backoff.
set -u

usage() {
    echo "usage: retry.sh --attempts N --base-delay S [--max-delay M] -- CMD [ARGS...]" >&2
}

is_uint() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

ATTEMPTS=""
BASE=""
MAX=""
SAW_SEP=0

while [ $# -gt 0 ]; do
    case "$1" in
        --attempts)   [ $# -ge 2 ] || { usage; exit 2; }; ATTEMPTS="$2"; shift 2 ;;
        --base-delay) [ $# -ge 2 ] || { usage; exit 2; }; BASE="$2"; shift 2 ;;
        --max-delay)  [ $# -ge 2 ] || { usage; exit 2; }; MAX="$2"; shift 2 ;;
        --)           SAW_SEP=1; shift; break ;;
        *)            usage; exit 2 ;;
    esac
done

[ "$SAW_SEP" -eq 1 ] || { usage; exit 2; }
[ $# -ge 1 ] || { usage; exit 2; }
is_uint "$ATTEMPTS" || { usage; exit 2; }
[ "$ATTEMPTS" -ge 1 ] || { usage; exit 2; }
is_uint "$BASE" || { usage; exit 2; }
if [ -n "$MAX" ]; then
    is_uint "$MAX" || { usage; exit 2; }
fi

k=1
while : ; do
    "$@"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        exit 0
    fi
    printf 'attempt %d/%d failed with %d\n' "$k" "$ATTEMPTS" "$rc" >&2
    if [ "$k" -ge "$ATTEMPTS" ]; then
        exit "$rc"
    fi
    delay=$(( BASE * (1 << (k - 1)) ))
    if [ -n "$MAX" ] && [ "$delay" -gt "$MAX" ]; then
        delay="$MAX"
    fi
    sleep "$delay"
    k=$((k + 1))
done
