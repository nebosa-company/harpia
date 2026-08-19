#!/usr/bin/env bash
# hidden - core behaviour: the functions, used the way another script would
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/stats.sh"
[ -f "$T" ] || { echo "missing stats.sh" >&2; exit 1; }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
fails=0
eq() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$2" "$3" >&2
    fails=$((fails + 1))
}
# Source stats.sh in a fresh shell and run one snippet against it.
drive() {
    {
        printf 'source %q\n' "$T"
        printf '%s\n' "$1"
    } > "$W/drv.sh"
    bash "$W/drv.sh" > "$W/.out" 2> "$W/.err" < "${2:-/dev/null}"
    RC=$?
    OUT="$(cat "$W/.out")"
    ERR="$(cat "$W/.err")"
}

{
    printf '# a comment\n'
    printf '  alpha\t5\tx  \n'
    printf 'beta\t60\ty\n'
    printf '\n'
    printf '   \t \n'
    printf '   # indented comment\n'
    printf 'gamma\t20\tz\n'
    printf 'delta\t15\tw\n'
} > "$W/data.tsv"

# sourcing alone must do nothing at all
drive ':'
eq "sourcing rc" 0 "$RC"
eq "sourcing wrote nothing to stdout" "" "$OUT"
eq "sourcing wrote nothing to stderr" "" "$ERR"

drive "read_records $(printf '%q' "$W/data.tsv")"
eq "read_records rc" 0 "$RC"
eq "read_records" "$(printf 'alpha\t5\tx\nbeta\t60\ty\ngamma\t20\tz\ndelta\t15\tw')" "$OUT"
eq "read_records stderr" "" "$ERR"

drive "read_records $(printf '%q' "$W/nope.tsv")"
eq "read_records missing rc" 1 "$RC"
eq "read_records missing stderr" "no such file: $W/nope.tsv" "$ERR"
eq "read_records missing stdout" "" "$OUT"

printf 'a\tb\tc\nd\te\tf\nlonely\n' > "$W/fields.tsv"
drive 'field 2' "$W/fields.tsv"
eq "field 2 rc" 0 "$RC"
eq "field 2" "$(printf 'b\ne\n')" "$OUT"

drive 'field 1' "$W/fields.tsv"
eq "field 1" "$(printf 'a\nd\nlonely')" "$OUT"

drive 'field 3' "$W/fields.tsv"
eq "field 3" "$(printf 'c\nf\n')" "$OUT"

drive 'field 0' "$W/fields.tsv"
eq "field 0 rc" 2 "$RC"
eq "field 0 stderr" "bad field: 0" "$ERR"
eq "field 0 stdout" "" "$OUT"

drive 'field x' "$W/fields.tsv"
eq "field x rc" 2 "$RC"
eq "field x stderr" "bad field: x" "$ERR"

printf '5\n60\n20\n15\n' > "$W/nums.txt"
drive 'summarize' "$W/nums.txt"
eq "summarize rc" 0 "$RC"
eq "summarize" "count=4 sum=100 min=5 max=60 mean=25.00" "$OUT"

printf '\n' > "$W/none.txt"
: > "$W/none.txt"
drive 'summarize' "$W/none.txt"
eq "summarize empty rc" 1 "$RC"
eq "summarize empty stdout" "" "$OUT"

printf '5\nnope\n7\n' > "$W/bad.txt"
drive 'summarize' "$W/bad.txt"
eq "summarize bad rc" 3 "$RC"
eq "summarize bad stderr" "not a number: nope" "$ERR"
eq "summarize bad stdout" "" "$OUT"

# the three of them compose, which is the whole point of the split
drive "read_records $(printf '%q' "$W/data.tsv") | field 2 | summarize"
eq "composed rc" 0 "$RC"
eq "composed" "count=4 sum=100 min=5 max=60 mean=25.00" "$OUT"

exit $((fails > 0 ? 1 : 0))
