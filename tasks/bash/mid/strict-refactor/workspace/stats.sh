#!/usr/bin/env bash
# Column statistics over a tab-separated file.

FIELD=""
FILE=""

if [ "${1-}" = "--field" ]; then
    FIELD="${2-}"
    FILE="${3-}"
fi

if [ -z "$FIELD" ] || [ -z "$FILE" ]; then
    echo "usage: stats.sh --field N FILE" >&2
    exit 2
fi

cat "$FILE" 2>/dev/null \
    | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//' \
    | grep -v -e '^$' -e '^#' \
    | cut -f "$FIELD" \
    | awk '
        {
            n++
            s += $1
            if (n == 1 || $1 + 0 < mn) mn = $1 + 0
            if (n == 1 || $1 + 0 > mx) mx = $1 + 0
        }
        END {
            if (n > 0) printf "count=%d sum=%d min=%d max=%d mean=%.2f\n", n, s, mn, mx, s / n
        }
    '

exit 0
