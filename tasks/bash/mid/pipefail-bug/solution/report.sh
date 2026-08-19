#!/usr/bin/env bash
# Build the daily record file from a raw export.
set -u
export LC_ALL=C

if [ $# -ne 2 ]; then
    echo "usage: report.sh INPUT OUTDIR" >&2
    exit 2
fi

INPUT="$1"
OUTDIR="$2"

if [ ! -f "$INPUT" ]; then
    echo "input not found: $INPUT" >&2
    exit 1
fi

mkdir -p "$OUTDIR" || exit 1

if [ -n "${PREPROCESS:-}" ]; then
    SOURCE=(bash "$PREPROCESS" "$INPUT")
else
    SOURCE=(cat "$INPUT")
fi

"${SOURCE[@]}" \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | grep -v -e '^$' -e '^#' \
    | sort -u > "$OUTDIR/records.txt"
source_status=${PIPESTATUS[0]}

count=$(wc -l < "$OUTDIR/records.txt")
printf 'records: %d\n' "$count"

if [ "$source_status" -ne 0 ]; then
    exit "$source_status"
fi

rm -f -- "$OUTDIR/rejects.txt"
rejects=0
while IFS= read -r r; do
    if [[ ! "$r" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        printf '%s\n' "$r" >> "$OUTDIR/rejects.txt"
        rejects=$((rejects + 1))
    fi
done < "$OUTDIR/records.txt"

if [ "$rejects" -gt 0 ]; then
    printf 'rejected: %d\n' "$rejects" >&2
    exit 3
fi

exit 0
