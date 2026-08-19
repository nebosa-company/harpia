#!/usr/bin/env bash
# Log rotation under an exclusive lock.
set -u
export LC_ALL=C

usage() {
    echo "usage: rotate.sh --file LOG --keep K [--max-bytes B] [--wait S]" >&2
}

is_uint() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

LOG=""
KEEP=""
MAXB="1048576"
WAIT="10"

while [ $# -gt 0 ]; do
    case "$1" in
        --file)      [ $# -ge 2 ] || { usage; exit 2; }; LOG="$2"; shift 2 ;;
        --keep)      [ $# -ge 2 ] || { usage; exit 2; }; KEEP="$2"; shift 2 ;;
        --max-bytes) [ $# -ge 2 ] || { usage; exit 2; }; MAXB="$2"; shift 2 ;;
        --wait)      [ $# -ge 2 ] || { usage; exit 2; }; WAIT="$2"; shift 2 ;;
        *)           usage; exit 2 ;;
    esac
done

[ -n "$LOG" ] || { usage; exit 2; }
[ -n "$KEEP" ] || { usage; exit 2; }
is_uint "$KEEP" || { usage; exit 2; }
[ "$KEEP" -ge 1 ] || { usage; exit 2; }
is_uint "$MAXB" || { usage; exit 2; }
is_uint "$WAIT" || { usage; exit 2; }

if [ ! -f "$LOG" ]; then
    printf 'no such file: %s\n' "$LOG" >&2
    exit 1
fi

exec 9> "$LOG.lock" || exit 1
if ! flock -w "$WAIT" -x 9; then
    printf 'busy: %s\n' "$LOG" >&2
    exit 4
fi

size="$(stat -c %s -- "$LOG")"
if [ "$size" -lt "$MAXB" ]; then
    exit 0
fi

for f in "$LOG".*; do
    [ -e "$f" ] || continue
    suf="${f##*.}"
    is_uint "$suf" || continue
    if [ "$suf" -ge "$KEEP" ]; then
        rm -f -- "$f"
    fi
done

i=$((KEEP - 1))
while [ "$i" -ge 1 ]; do
    if [ -e "$LOG.$i" ]; then
        mv -- "$LOG.$i" "$LOG.$((i + 1))"
    fi
    i=$((i - 1))
done

mv -- "$LOG" "$LOG.1"
: > "$LOG"
printf 'rotated: %s\n' "$LOG"
