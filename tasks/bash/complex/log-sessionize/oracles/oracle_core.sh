#!/usr/bin/env bash
# hidden - core behaviour
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

{
    printf '# collector merge, unsorted on purpose\n'
    printf '9000\tcarol\tview\t10\n'
    printf '1200\talice\tclick\t30\n'
    printf '1100\tbob\tview\t50\n'
    printf '\n'
    printf '1000\talice\tview\t120\n'
    printf '1300\tbob\tclick\t25\n'
    printf '5000\talice\tview\t200\n'
} > "$W/events.tsv"

run "$W/events.tsv"
eq "default rc" 0 "$RC"
eq "default stderr" "" "$ERR"
eq "default sessions" "$(printf 'alice\t1\t1000\t1200\t2\t200\t150\nalice\t2\t5000\t5000\t1\t0\t200\nbob\t1\t1100\t1300\t2\t200\t75\ncarol\t1\t9000\t9000\t1\t0\t10')" "$OUT"

run --gap 5000 "$W/events.tsv"
eq "wide gap rc" 0 "$RC"
eq "wide gap" "$(printf 'alice\t1\t1000\t5000\t3\t4000\t350\nbob\t1\t1100\t1300\t2\t200\t75\ncarol\t1\t9000\t9000\t1\t0\t10')" "$OUT"

run --gap 0 "$W/events.tsv"
eq "zero gap rc" 0 "$RC"
eq "zero gap" "$(printf 'alice\t1\t1000\t1000\t1\t0\t120\nalice\t2\t1200\t1200\t1\t0\t30\nalice\t3\t5000\t5000\t1\t0\t200\nbob\t1\t1100\t1100\t1\t0\t50\nbob\t2\t1300\t1300\t1\t0\t25\ncarol\t1\t9000\t9000\t1\t0\t10')" "$OUT"

run --summary "$W/events.tsv"
eq "summary rc" 0 "$RC"
eq "summary" "$(printf 'users\t3\nsessions\t4\nmean_events\t1.50\nmean_duration\t100.00\np50_duration\t0\np90_duration\t200')" "$OUT"

run --summary --gap 5000 "$W/events.tsv"
eq "summary wide gap" "$(printf 'users\t3\nsessions\t3\nmean_events\t2.00\nmean_duration\t1400.00\np50_duration\t200\np90_duration\t4000')" "$OUT"

# the gap boundary is strict: a gap exactly equal to S stays in the session
{
    printf '0\tdave\ta\t1\n'
    printf '1800\tdave\tb\t2\n'
} > "$W/boundary.tsv"
run "$W/boundary.tsv"
eq "gap equal to S" "$(printf 'dave\t1\t0\t1800\t2\t1800\t3')" "$OUT"
run --gap 1799 "$W/boundary.tsv"
eq "gap one below S" "$(printf 'dave\t1\t0\t0\t1\t0\t1\ndave\t2\t1800\t1800\t1\t0\t2')" "$OUT"

# users sort in byte order, not by first appearance
{
    printf '10\tzulu\ta\t1\n'
    printf '10\tAlpha\ta\t1\n'
    printf '10\tmike\ta\t1\n'
} > "$W/order.tsv"
run "$W/order.tsv"
eq "user ordering" "$(printf 'Alpha\t1\t10\t10\t1\t0\t1\nmike\t1\t10\t10\t1\t0\t1\nzulu\t1\t10\t10\t1\t0\t1')" "$OUT"

exit $((fails > 0 ? 1 : 0))
