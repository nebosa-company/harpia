#!/usr/bin/env bash
# hidden - edge cases
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/sessionize.sh"
[ -f "$T" ] || { echo "missing sessionize.sh" >&2; exit 1; }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
fails=0
eq() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL %s\n  want:\n%s\n  got:\n%s\n' "$1" "$2" "$3" >&2
    fails=$((fails + 1))
}
run() {
    OUT="$(bash "$T" "$@" 2>"$W/.err")"
    RC=$?
    ERR="$(cat "$W/.err")"
}

# every shape of malformed line, with good rows in between
{
    printf '100\tzoe\tview\t5\n'          # 1 good
    printf 'notanumber\tzoe\tview\t5\n'   # 2 bad epoch
    printf '200\tzoe\tview\n'             # 3 too few fields
    printf '300\tzoe\tview\t5\textra\n'   # 4 too many fields
    printf '400\t\tview\t5\n'             # 5 empty user
    printf '500\tzoe\tview\tnope\n'       # 6 bad ms
    printf '600\tzoe\tclick\t7\n'         # 7 good
    printf '# a comment\n'                # 8
    printf '\n'                           # 9
    printf '   \n'                        # 10
} > "$W/messy.tsv"

run "$W/messy.tsv"
eq "messy rc" 0 "$RC"
eq "messy stderr" "malformed: 5" "$ERR"
eq "messy sessions" "$(printf 'zoe\t1\t100\t600\t2\t500\t12')" "$OUT"

run --strict "$W/messy.tsv"
eq "strict rc" 3 "$RC"
eq "strict stderr" "bad line 2" "$ERR"
eq "strict stdout" "" "$OUT"

run --strict --summary "$W/messy.tsv"
eq "strict summary rc" 3 "$RC"
eq "strict summary stdout" "" "$OUT"

# a clean file is not affected by --strict
printf '1\tann\ta\t1\n2\tann\tb\t2\n' > "$W/clean.tsv"
run --strict "$W/clean.tsv"
eq "strict clean rc" 0 "$RC"
eq "strict clean stderr" "" "$ERR"
eq "strict clean" "$(printf 'ann\t1\t1\t2\t2\t1\t3')" "$OUT"

# same-epoch events belong to one session and are all counted
printf '50\tbea\ta\t1\n50\tbea\tb\t2\n50\tbea\tc\t3\n' > "$W/ties.tsv"
run --gap 0 "$W/ties.tsv"
eq "same epoch" "$(printf 'bea\t1\t50\t50\t3\t0\t6')" "$OUT"

# an empty file, and one that is nothing but noise
: > "$W/empty.tsv"
run "$W/empty.tsv"
eq "empty rc" 0 "$RC"
eq "empty stdout" "" "$OUT"
eq "empty stderr" "" "$ERR"
run --summary "$W/empty.tsv"
eq "empty summary rc" 0 "$RC"
eq "empty summary" "$(printf 'users\t0\nsessions\t0\nmean_events\t0.00\nmean_duration\t0.00\np50_duration\t0\np90_duration\t0')" "$OUT"

printf '# nothing\n\n' > "$W/noise.tsv"
run --summary "$W/noise.tsv"
eq "noise summary" "$(printf 'users\t0\nsessions\t0\nmean_events\t0.00\nmean_duration\t0.00\np50_duration\t0\np90_duration\t0')" "$OUT"

# a file where every line is malformed
printf 'x\ny\n' > "$W/allbad.tsv"
run "$W/allbad.tsv"
eq "all bad rc" 0 "$RC"
eq "all bad stdout" "" "$OUT"
eq "all bad stderr" "malformed: 2" "$ERR"

# percentiles over an odd number of sessions
{
    printf '0\tp\ta\t0\n'
    printf '10\tp\tb\t0\n'
    printf '100000\tq\ta\t0\n'
    printf '100020\tq\tb\t0\n'
    printf '200000\tr\ta\t0\n'
    printf '200030\tr\tb\t0\n'
} > "$W/three.tsv"
run --summary "$W/three.tsv"
eq "odd percentiles" "$(printf 'users\t3\nsessions\t3\nmean_events\t2.00\nmean_duration\t20.00\np50_duration\t20\np90_duration\t30')" "$OUT"

# one single session
printf '7\tsolo\ta\t42\n' > "$W/solo.tsv"
run --summary "$W/solo.tsv"
eq "single session summary" "$(printf 'users\t1\nsessions\t1\nmean_events\t1.00\nmean_duration\t0.00\np50_duration\t0\np90_duration\t0')" "$OUT"

# large millisecond sums stay exact
{
    printf '1\tbig\ta\t2000000000\n'
    printf '2\tbig\tb\t2000000001\n'
} > "$W/big.tsv"
run "$W/big.tsv"
eq "large sum" "$(printf 'big\t1\t1\t2\t2\t1\t4000000001')" "$OUT"

# a user name containing spaces is fine, tabs separate the fields
printf '1\ttwo words\ta\t1\n5\ttwo words\tb\t1\n' > "$W/spaces.tsv"
run "$W/spaces.tsv"
eq "spaced user" "$(printf 'two words\t1\t1\t5\t2\t4\t2')" "$OUT"

# file and usage errors
run "$W/absent.tsv"
eq "missing file rc" 1 "$RC"
eq "missing file stderr" "no such file: $W/absent.tsv" "$ERR"

run
eq "no file rc" 2 "$RC"
run --summary
eq "summary with no file rc" 2 "$RC"
run --gap 500
eq "gap with no file rc" 2 "$RC"
run --gap -1 "$W/clean.tsv"
eq "negative gap rc" 2 "$RC"
run --gap abc "$W/clean.tsv"
eq "non-numeric gap rc" 2 "$RC"
run --gap
eq "dangling --gap rc" 2 "$RC"
run --bogus "$W/clean.tsv"
eq "unknown option rc" 2 "$RC"
run "$W/clean.tsv" "$W/solo.tsv"
eq "two files rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
