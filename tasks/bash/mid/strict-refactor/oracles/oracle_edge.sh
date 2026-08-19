#!/usr/bin/env bash
# hidden - edge cases: the new strictness, and the shape it has to have
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
run() {
    OUT="$(bash "$T" "$@" 2>"$W/.err")"
    RC=$?
    ERR="$(cat "$W/.err")"
}

# the strict shell options are switched on
if ! grep -qx 'set -euo pipefail' "$T"; then
    echo "FAIL stats.sh has no 'set -euo pipefail' line" >&2
    fails=$((fails + 1))
fi

{
    printf '# a comment\n'
    printf 'alpha\t5\tx\n'
    printf 'beta\t60\ty\n'
    printf '\n'
    printf 'gamma\t20\tz\n'
    printf 'delta\t15\tw\n'
} > "$W/data.tsv"

# the behaviour the visible tests pin down still holds
run --field 2 "$W/data.tsv"
eq "cli rc" 0 "$RC"
eq "cli summary" "count=4 sum=100 min=5 max=60 mean=25.00" "$OUT"
eq "cli stderr" "" "$ERR"

# a missing file is no longer silent
run --field 2 "$W/absent.tsv"
eq "missing file rc" 1 "$RC"
eq "missing file stderr" "no such file: $W/absent.tsv" "$ERR"
eq "missing file stdout" "" "$OUT"

# a bad field number
run --field 0 "$W/data.tsv"
eq "field 0 rc" 2 "$RC"
eq "field 0 stderr" "bad field: 0" "$ERR"
run --field zzz "$W/data.tsv"
eq "field zzz rc" 2 "$RC"
eq "field zzz stderr" "bad field: zzz" "$ERR"

# a file with nothing but noise
printf '# nothing\n\n   \n' > "$W/noise.tsv"
run --field 1 "$W/noise.tsv"
eq "no records rc" 4 "$RC"
eq "no records stderr" "no records" "$ERR"
eq "no records stdout" "" "$OUT"

: > "$W/blank.tsv"
run --field 1 "$W/blank.tsv"
eq "empty file rc" 4 "$RC"
eq "empty file stderr" "no records" "$ERR"

# a non-numeric value in the chosen column
run --field 1 "$W/data.tsv"
eq "non-numeric rc" 3 "$RC"
eq "non-numeric stderr" "not a number: alpha" "$ERR"
eq "non-numeric stdout" "" "$OUT"

# negative values and a single record
printf 'a\t-10\nb\t-2\nc\t-30\n' > "$W/neg.tsv"
run --field 2 "$W/neg.tsv"
eq "negatives" "count=3 sum=-42 min=-30 max=-2 mean=-14.00" "$OUT"

printf 'only\t7\n' > "$W/one.tsv"
run --field 2 "$W/one.tsv"
eq "single record" "count=1 sum=7 min=7 max=7 mean=7.00" "$OUT"

# mean is always two decimals
printf 'a\t1\nb\t2\n' > "$W/two.tsv"
run --field 2 "$W/two.tsv"
eq "two decimals" "count=2 sum=3 min=1 max=2 mean=1.50" "$OUT"

# a short record contributes an empty value, which is not a number
printf 'a\t1\nb\n' > "$W/short.tsv"
run --field 2 "$W/short.tsv"
eq "short record rc" 3 "$RC"
eq "short record stderr" "not a number: " "$ERR"

# usage errors
run
eq "no arguments rc" 2 "$RC"
run --field 2
eq "no file rc" 2 "$RC"
run "$W/data.tsv"
eq "no --field rc" 2 "$RC"
run --field
eq "dangling --field rc" 2 "$RC"
run --bogus 2 "$W/data.tsv"
eq "unknown option rc" 2 "$RC"
run --field 2 "$W/data.tsv" "$W/one.tsv"
eq "two files rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
