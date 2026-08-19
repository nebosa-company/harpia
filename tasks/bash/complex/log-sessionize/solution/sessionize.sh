#!/usr/bin/env bash
# Sessionizing log analytics.
set -u
export LC_ALL=C

usage() {
    echo "usage: sessionize.sh [--gap S] [--summary] [--strict] FILE" >&2
}

GAP=1800
SUMMARY=0
STRICT=0
FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --gap)     [ $# -ge 2 ] || { usage; exit 2; }; GAP="$2"; shift 2 ;;
        --summary) SUMMARY=1; shift ;;
        --strict)  STRICT=1; shift ;;
        --)        shift ;;
        -*)        usage; exit 2 ;;
        *)         [ -z "$FILE" ] || { usage; exit 2; }; FILE="$1"; shift ;;
    esac
done

case "$GAP" in
    ''|*[!0-9]*) usage; exit 2 ;;
esac
[ -n "$FILE" ] || { usage; exit 2; }
if [ ! -f "$FILE" ]; then
    printf 'no such file: %s\n' "$FILE" >&2
    exit 1
fi

TAB=$'\t'

good="$(awk -F'\t' -v strict="$STRICT" '
    /^#/ { next }
    /^[[:space:]]*$/ { next }
    {
        if (NF == 4 && $1 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ && $2 != "") {
            printf "%d\t%s\t%s\t%s\n", NR, $1, $2, $4
            next
        }
        if (strict == 1) {
            printf "bad line %d\n", NR > "/dev/stderr"
            failed = 1
            exit 3
        }
        mal++
    }
    END {
        if (failed) exit 3
        if (mal) printf "malformed: %d\n", mal > "/dev/stderr"
    }
' "$FILE")"
rc=$?
if [ "$rc" -ne 0 ]; then
    exit "$rc"
fi

rows=""
if [ -n "$good" ]; then
    rows="$(
        printf '%s\n' "$good" |
            sort -s -t"$TAB" -k3,3 -k2,2n |
            awk -F'\t' -v gap="$GAP" '
                function emit() {
                    printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\n", curu, sess, start, last, cnt, last - start, tot
                }
                {
                    e = $2 + 0
                    u = $3
                    m = $4 + 0
                    if (!seen || u != curu) {
                        if (seen) emit()
                        seen = 1
                        curu = u; sess = 1; start = e; last = e; cnt = 1; tot = m
                        next
                    }
                    if (e - last > gap) {
                        emit()
                        sess++; start = e; last = e; cnt = 1; tot = m
                        next
                    }
                    last = e; cnt++; tot += m
                }
                END { if (seen) emit() }
            '
    )"
fi

if [ "$SUMMARY" -eq 0 ]; then
    if [ -n "$rows" ]; then
        printf '%s\n' "$rows"
    fi
    exit 0
fi

durs="$(printf '%s\n' "$rows" | awk -F'\t' 'NF > 0 { print $6 }' | sort -n)"
printf '%s\n' "$rows" | awk -F'\t' -v durs="$durs" '
    NF > 0 {
        users[$1] = 1
        n++
        ev += $5
        du += $6
    }
    END {
        printf "users\t%d\n", length(users)
        printf "sessions\t%d\n", n
        if (n == 0) {
            printf "mean_events\t0.00\nmean_duration\t0.00\np50_duration\t0\np90_duration\t0\n"
            exit
        }
        printf "mean_events\t%.2f\n", ev / n
        printf "mean_duration\t%.2f\n", du / n
        split(durs, D, "\n")
        i50 = int((50 * n + 99) / 100)
        i90 = int((90 * n + 99) / 100)
        printf "p50_duration\t%d\n", D[i50]
        printf "p90_duration\t%d\n", D[i90]
    }
'
