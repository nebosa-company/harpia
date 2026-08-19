#!/usr/bin/env bash
# Visible tests for stats.sh. These describe behaviour that must not change.
set -u
export LC_ALL=C
cd "$(dirname "$0")/.." || exit 1

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
fails=0
eq() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$2" "$3" >&2
    fails=$((fails + 1))
}
run() {
    OUT="$(bash stats.sh "$@" 2>"$W/.err")"
    RC=$?
    ERR="$(cat "$W/.err")"
}

{
    printf '# a comment\n'
    printf 'alpha\t5\tx\n'
    printf 'beta\t60\ty\n'
    printf '\n'
    printf 'gamma\t20\tz\n'
    printf 'delta\t15\tw\n'
} > "$W/data.tsv"

run --field 2 "$W/data.tsv"
eq "summary rc" 0 "$RC"
eq "summary" "count=4 sum=100 min=5 max=60 mean=25.00" "$OUT"

run --field 2 "$W/data.tsv"
eq "summary is stable" "count=4 sum=100 min=5 max=60 mean=25.00" "$OUT"

run --field 2
eq "missing file argument rc" 2 "$RC"

run
eq "no arguments rc" 2 "$RC"

if [ "$fails" -eq 0 ]; then
    echo "visible tests: ok"
else
    echo "visible tests: $fails failure(s)" >&2
fi
exit $((fails > 0 ? 1 : 0))
