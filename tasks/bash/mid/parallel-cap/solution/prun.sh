#!/usr/bin/env bash
# Parallel command runner with a concurrency cap.
set -u
export LC_ALL=C

usage() {
    echo "usage: prun.sh -j N FILE" >&2
}

JOBS=""
FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        -j) [ $# -ge 2 ] || { usage; exit 2; }; JOBS="$2"; shift 2 ;;
        --) shift ;;
        -*) usage; exit 2 ;;
        *)  [ -z "$FILE" ] || { usage; exit 2; }; FILE="$1"; shift ;;
    esac
done

[ -n "$JOBS" ] || { usage; exit 2; }
case "$JOBS" in
    ''|*[!0-9]*) usage; exit 2 ;;
esac
[ "$JOBS" -ge 1 ] || { usage; exit 2; }
[ -n "$FILE" ] || { usage; exit 2; }
if [ ! -f "$FILE" ]; then
    printf 'no such file: %s\n' "$FILE" >&2
    exit 1
fi

STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"' EXIT

LINES=()
while IFS= read -r line || [ -n "$line" ]; do
    LINES+=("$line")
done < "$FILE"

running=0
lineno=0
for line in ${LINES[@]+"${LINES[@]}"}; do
    lineno=$((lineno + 1))
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if [ "$running" -ge "$JOBS" ]; then
        wait -n
        running=$((running - 1))
    fi
    {
        bash -c "$line" < /dev/null
        printf '%d\n' "$?" > "$STATE/$lineno"
    } &
    running=$((running + 1))
done
wait

ok=0
bad=0
while IFS= read -r n; do
    st="$(cat "$STATE/$n")"
    printf '%s\t%s\n' "$n" "$st"
    if [ "$st" -eq 0 ]; then
        ok=$((ok + 1))
    else
        bad=$((bad + 1))
    fi
done < <(ls -1 "$STATE" 2>/dev/null | sort -n)

printf 'ok: %d failed: %d\n' "$ok" "$bad"
[ "$bad" -eq 0 ]
