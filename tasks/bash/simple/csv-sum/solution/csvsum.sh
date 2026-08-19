#!/usr/bin/env bash
# CSV column summer.
set -u
export LC_ALL=C

usage() {
    echo "usage: csvsum.sh --sum COL [--group-by COL] [--where COL=VALUE] FILE" >&2
}

SUM=""
GROUP=""
WHERE=""
HASWHERE=""
FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --sum)      [ $# -ge 2 ] || { usage; exit 2; }; SUM="$2"; shift 2 ;;
        --group-by) [ $# -ge 2 ] || { usage; exit 2; }; GROUP="$2"; shift 2 ;;
        --where)    [ $# -ge 2 ] || { usage; exit 2; }; WHERE="$2"; HASWHERE=1; shift 2 ;;
        --)         shift; break ;;
        -*)         usage; exit 2 ;;
        *)          [ -z "$FILE" ] || { usage; exit 2; }; FILE="$1"; shift ;;
    esac
done
if [ $# -gt 0 ]; then
    [ -z "$FILE" ] || { usage; exit 2; }
    FILE="$1"; shift
    [ $# -eq 0 ] || { usage; exit 2; }
fi

[ -n "$SUM" ] || { usage; exit 2; }
[ -n "$FILE" ] || { usage; exit 2; }
if [ -n "$HASWHERE" ]; then
    case "$WHERE" in
        *=*) ;;
        *) usage; exit 2 ;;
    esac
fi
if [ ! -f "$FILE" ]; then
    printf 'no such file: %s\n' "$FILE" >&2
    exit 1
fi

WCOL="${WHERE%%=*}"
WVAL="${WHERE#*=}"
TAB=$'\t'

awk -F, \
    -v sumcol="$SUM" -v groupcol="$GROUP" \
    -v wcol="$WCOL" -v wval="$WVAL" -v haswhere="$HASWHERE" '
function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
NR == 1 {
    ncols = NF
    for (i = 1; i <= NF; i++) idx[trim($i)] = i
    if (!(sumcol in idx)) { printf "no such column: %s\n", sumcol > "/dev/stderr"; bad = 4; exit 4 }
    if (groupcol != "" && !(groupcol in idx)) { printf "no such column: %s\n", groupcol > "/dev/stderr"; bad = 4; exit 4 }
    if (haswhere != "" && !(wcol in idx)) { printf "no such column: %s\n", wcol > "/dev/stderr"; bad = 4; exit 4 }
    next
}
/^[ \t\r]*$/ { next }
{
    if (NF != ncols) { skipped++; next }
    if (haswhere != "" && trim($(idx[wcol])) != wval) next
    v = trim($(idx[sumcol]))
    if (v !~ /^-?[0-9]+(\.[0-9]+)?$/) {
        printf "bad number: %s on line %d\n", v, NR > "/dev/stderr"
        bad = 3
        exit 3
    }
    if (groupcol != "") {
        k = trim($(idx[groupcol]))
        g[k] += v + 0
    } else {
        total += v + 0
    }
}
END {
    if (bad) exit bad
    if (skipped) printf "skipped: %d\n", skipped > "/dev/stderr"
    if (groupcol != "") {
        for (k in g) printf "%s\t%.2f\n", k, g[k]
    } else {
        printf "%.2f\n", total + 0
    }
}
' "$FILE" | sort -t"$TAB" -k1,1

exit "${PIPESTATUS[0]}"
