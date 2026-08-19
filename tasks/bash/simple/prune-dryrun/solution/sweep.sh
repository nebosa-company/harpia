#!/usr/bin/env bash
# Stale-file sweeper: report by default, delete only with --apply.
set -u
export LC_ALL=C

usage() {
    echo "usage: sweep.sh --root DIR --older-than N [--exclude GLOB]... [--apply]" >&2
}

ROOT=""
DAYS=""
APPLY=0
EXCLUDES=()

while [ $# -gt 0 ]; do
    case "$1" in
        --root)       [ $# -ge 2 ] || { usage; exit 2; }; ROOT="$2"; shift 2 ;;
        --older-than) [ $# -ge 2 ] || { usage; exit 2; }; DAYS="$2"; shift 2 ;;
        --exclude)    [ $# -ge 2 ] || { usage; exit 2; }; EXCLUDES+=("$2"); shift 2 ;;
        --apply)      APPLY=1; shift ;;
        *)            usage; exit 2 ;;
    esac
done

[ -n "$ROOT" ] || { usage; exit 2; }
[ -n "$DAYS" ] || { usage; exit 2; }
case "$DAYS" in
    ''|*[!0-9]*) usage; exit 2 ;;
esac
if [ ! -d "$ROOT" ]; then
    printf 'not a directory: %s\n' "$ROOT" >&2
    exit 1
fi

ROOT="${ROOT%/}"
cutoff=$(( $(date +%s) - DAYS * 86400 ))

candidates=()
while IFS= read -r -d '' f; do
    mt="$(stat -c %Y -- "$f")" || continue
    [ "$mt" -lt "$cutoff" ] || continue
    base="${f##*/}"
    skip=0
    for g in ${EXCLUDES[@]+"${EXCLUDES[@]}"}; do
        case "$base" in
            $g) skip=1; break ;;
        esac
    done
    [ "$skip" -eq 0 ] || continue
    candidates+=("${f#"$ROOT"/}")
done < <(
    find "$ROOT" \
        \( -type d \( -name .git -o -name node_modules -o -name .cache \) \) -prune -o \
        -type f -print0
)

n=0
if [ ${#candidates[@]} -gt 0 ]; then
    while IFS= read -r -d '' rel; do
        printf '%s\n' "$rel"
        if [ "$APPLY" -eq 1 ]; then
            rm -f -- "$ROOT/$rel"
        fi
        n=$((n + 1))
    done < <(printf '%s\0' "${candidates[@]}" | sort -z)
fi
printf 'candidates: %d\n' "$n"
