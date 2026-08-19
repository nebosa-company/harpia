#!/usr/bin/env bash
# Human-readable directory size report.
set -u
export LC_ALL=C

usage() {
    echo "usage: dirsize.sh [--top N] DIR" >&2
}

TOP=""
DIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --top)
            [ $# -ge 2 ] || { usage; exit 2; }
            TOP="$2"
            shift 2
            ;;
        --)
            shift
            ;;
        -*)
            usage
            exit 2
            ;;
        *)
            [ -z "$DIR" ] || { usage; exit 2; }
            DIR="$1"
            shift
            ;;
    esac
done

[ -n "$DIR" ] || { usage; exit 2; }
if [ -n "$TOP" ]; then
    case "$TOP" in
        ''|*[!0-9]*) usage; exit 2 ;;
    esac
    [ "$TOP" -ge 1 ] || { usage; exit 2; }
fi
if [ ! -d "$DIR" ]; then
    printf 'not a directory: %s\n' "$DIR" >&2
    exit 1
fi

TAB=$'\t'

human() {
    awk -v b="$1" 'BEGIN {
        if (b < 1024) { printf "%dB", b; exit }
        split("K M G T", u, " ")
        v = b / 1024
        i = 1
        while (v >= 1024 && i < 4) { v /= 1024; i++ }
        printf "%.1f%s", v, u[i]
    }'
}

rows=()
grand=0
while IFS= read -r -d '' d; do
    total="$(find "$d" -type f -printf '%s\n' | awk '{ s += $1 } END { print s + 0 }')"
    rows+=("$total$TAB${d##*/}")
    grand=$((grand + total))
done < <(find "$DIR" -mindepth 1 -maxdepth 1 -type d -print0)

if [ ${#rows[@]} -gt 0 ]; then
    n=0
    while IFS="$TAB" read -r total name; do
        n=$((n + 1))
        if [ -n "$TOP" ] && [ "$n" -gt "$TOP" ]; then
            break
        fi
        printf '%s\t%s\n' "$(human "$total")" "$name"
    done < <(printf '%s\n' "${rows[@]}" | sort -t"$TAB" -k1,1nr -k2,2)
fi
printf '%s\tTOTAL\n' "$(human "$grand")"
