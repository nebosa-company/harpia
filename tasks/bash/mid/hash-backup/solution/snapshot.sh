#!/usr/bin/env bash
# Content-addressed incremental snapshot.
set -u
export LC_ALL=C

usage() {
    echo "usage: snapshot.sh --source SRC --store DIR | snapshot.sh --verify DIR" >&2
}

SRC=""
STORE=""
VERIFY=""
MODE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --source) [ $# -ge 2 ] || { usage; exit 2; }; SRC="$2"; shift 2 ;;
        --store)  [ $# -ge 2 ] || { usage; exit 2; }; STORE="$2"; shift 2 ;;
        --verify) [ $# -ge 2 ] || { usage; exit 2; }; VERIFY="$2"; MODE=verify; shift 2 ;;
        *)        usage; exit 2 ;;
    esac
done

if [ -n "$MODE" ]; then
    [ -z "$SRC" ] && [ -z "$STORE" ] || { usage; exit 2; }
else
    [ -n "$SRC" ] && [ -n "$STORE" ] || { usage; exit 2; }
    MODE=snapshot
fi

digest() { sha256sum -- "$1" | cut -d' ' -f1; }

if [ "$MODE" = "verify" ]; then
    count=0
    bad=()
    if [ -d "$VERIFY/objects" ]; then
        while IFS= read -r -d '' o; do
            rest="${o##*/}"
            dir="${o%/*}"
            two="${dir##*/}"
            count=$((count + 1))
            if [ "$(digest "$o")" != "$two$rest" ]; then
                bad+=("$two$rest")
            fi
        done < <(find "$VERIFY/objects" -type f -print0 | sort -z)
    fi
    if [ ${#bad[@]} -gt 0 ]; then
        printf '%s\n' "${bad[@]}" | sort | while IFS= read -r b; do
            printf 'corrupt: %s\n' "$b" >&2
        done
        exit 5
    fi
    printf 'ok: %d\n' "$count"
    exit 0
fi

if [ ! -d "$SRC" ]; then
    printf 'no such directory: %s\n' "$SRC" >&2
    exit 1
fi

SRC="${SRC%/}"
mkdir -p -- "$STORE/objects" || exit 1

tmp="$STORE/.manifest.$$"
: > "$tmp" || exit 1
new=0
reused=0

while IFS= read -r -d '' f; do
    rel="${f#"$SRC"/}"
    h="$(digest "$f")"
    obj="$STORE/objects/${h:0:2}/${h:2}"
    if [ -e "$obj" ]; then
        reused=$((reused + 1))
    else
        mkdir -p -- "${obj%/*}" || exit 1
        cp -- "$f" "$obj" || exit 1
        new=$((new + 1))
    fi
    printf '%s\t%s\n' "$h" "$rel" >> "$tmp"
done < <(find "$SRC" -type f -print0 | sort -z)

mv -- "$tmp" "$STORE/manifest.tsv" || exit 1
printf 'new: %d reused: %d\n' "$new" "$reused"
