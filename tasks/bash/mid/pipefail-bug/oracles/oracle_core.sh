#!/usr/bin/env bash
# hidden - core behaviour
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/report.sh"
[ -f "$T" ] || { echo "missing report.sh" >&2; exit 1; }

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

{
    printf '# header comment\n'
    printf '  alpha  \n'
    printf 'beta\n'
    printf '\n'
    printf '  # indented comment\n'
    printf 'gamma\n'
    printf 'alpha\n'
    printf '\tdelta\t\n'
} > "$W/clean.txt"

O="$W/out"
run "$W/clean.txt" "$O"
eq "clean rc" 0 "$RC"
eq "clean stdout" "records: 4" "$OUT"
eq "clean stderr" "" "$ERR"
eq "clean records.txt" "$(printf 'alpha\nbeta\ndelta\ngamma')" "$(cat "$O/records.txt")"
if [ -e "$O/rejects.txt" ]; then
    echo "FAIL rejects.txt was created for a clean run" >&2
    fails=$((fails + 1))
fi

# unacceptable records
{
    printf 'good_one\n'
    printf 'bad space\n'
    printf 'also-good\n'
    printf 'bad/slash\n'
    printf 'ok.name\n'
} > "$W/dirty.txt"

R="$W/rout"
run "$W/dirty.txt" "$R"
eq "dirty rc" 3 "$RC"
eq "dirty stdout" "records: 5" "$OUT"
eq "dirty stderr" "rejected: 2" "$ERR"
eq "dirty records.txt" "$(printf 'also-good\nbad space\nbad/slash\ngood_one\nok.name')" "$(cat "$R/records.txt")"
eq "dirty rejects.txt" "$(printf 'bad space\nbad/slash')" "$(cat "$R/rejects.txt")"

# a second run rebuilds rejects.txt rather than appending to it
run "$W/dirty.txt" "$R"
eq "second dirty rc" 3 "$RC"
eq "second dirty stderr" "rejected: 2" "$ERR"
eq "rejects.txt rebuilt" "$(printf 'bad space\nbad/slash')" "$(cat "$R/rejects.txt")"

# a clean run into the same directory removes the stale rejects file
run "$W/clean.txt" "$R"
eq "clean over dirty rc" 0 "$RC"
eq "clean over dirty stdout" "records: 4" "$OUT"
if [ -e "$R/rejects.txt" ]; then
    echo "FAIL stale rejects.txt survived a clean run" >&2
    fails=$((fails + 1))
fi

# the output directory is created, however deep
run "$W/clean.txt" "$W/a/b/c"
eq "nested outdir rc" 0 "$RC"
eq "nested outdir records" "$(printf 'alpha\nbeta\ndelta\ngamma')" "$(cat "$W/a/b/c/records.txt")"

exit $((fails > 0 ? 1 : 0))
