#!/usr/bin/env bash
# Build the daily record file from a raw export.

if [ $# != 2 ]; then
    echo "usage: report.sh INPUT OUTDIR" >&2
    exit 2
fi

INPUT="$1"
OUTDIR="$2"

if [ ! -f "$INPUT" ]; then
    echo "input not found: $INPUT" >&2
    exit 1
fi

mkdir -p "$OUTDIR"

if [ -n "${PREPROCESS:-}" ]; then
    SOURCE=(bash "$PREPROCESS" "$INPUT")
else
    SOURCE=(cat "$INPUT")
fi

"${SOURCE[@]}" \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | grep -v -e '^$' -e '^#' \
    | sort -u > "$OUTDIR/records.txt"

count=0
cat "$OUTDIR/records.txt" | while IFS= read -r r; do
    count=$((count + 1))
done
echo "records: $count"

rejects=0
cat "$OUTDIR/records.txt" | while IFS= read -r r; do
    case "$r" in
        *[!A-Za-z0-9_.-]*)
            echo "$r" >> "$OUTDIR/rejects.txt"
            rejects=$((rejects + 1))
            ;;
    esac
done

if [ "$rejects" -gt 0 ]; then
    echo "rejected: $rejects" >&2
    exit 3
fi

exit 0
