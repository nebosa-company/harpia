#!/usr/bin/env bash
# hidden - core behaviour
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/tool.sh"
[ -f "$T" ] || { echo "missing tool.sh" >&2; exit 1; }

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

D="$W/store"

run -C "$D" add -n beta -V 'second value' -t prod
eq "add beta rc" 0 "$RC"
eq "add beta stdout" "added: beta" "$OUT"
eq "add beta stderr" "" "$ERR"

run -C "$D" add -n alpha -V 'first value' -t prod
eq "add alpha rc" 0 "$RC"
run -C "$D" add -n gamma -V 'third value' -t dev
eq "add gamma rc" 0 "$RC"
run -C "$D" add -n delta -V 'no tag given'
eq "add delta rc" 0 "$RC"

want="$(printf 'alpha\tfirst value\tprod\nbeta\tsecond value\tprod\ndelta\tno tag given\t-\ngamma\tthird value\tdev')"
run -C "$D" list
eq "list rc" 0 "$RC"
eq "list" "$want" "$OUT"

run -C "$D" list -t prod
eq "list by tag" "$(printf 'alpha\tfirst value\tprod\nbeta\tsecond value\tprod')" "$OUT"

run -C "$D" list -t dev
eq "list dev" "$(printf 'gamma\tthird value\tdev')" "$OUT"

run -C "$D" list -t '-'
eq "list default tag" "$(printf 'delta\tno tag given\t-')" "$OUT"

run -C "$D" list -t nosuch
eq "list unknown tag rc" 0 "$RC"
eq "list unknown tag" "" "$OUT"

run -C "$D" get -n beta
eq "get rc" 0 "$RC"
eq "get" "second value" "$OUT"

run -C "$D" add -n beta -V 'again'
eq "duplicate rc" 4 "$RC"
eq "duplicate stderr" "duplicate: beta" "$ERR"

run -C "$D" remove -n beta
eq "remove rc" 0 "$RC"
eq "remove stdout" "removed: beta" "$OUT"

run -C "$D" list
eq "list after remove" "$(printf 'alpha\tfirst value\tprod\ndelta\tno tag given\t-\ngamma\tthird value\tdev')" "$OUT"

run -C "$D" get -n beta
eq "get removed rc" 5 "$RC"
eq "get removed stderr" "not found: beta" "$ERR"

run -C "$D" remove -n beta
eq "remove twice rc" 5 "$RC"
eq "remove twice stderr" "not found: beta" "$ERR"

# the name is free again
run -C "$D" add -n beta -V 'reborn' -t dev
eq "re-add rc" 0 "$RC"
run -C "$D" get -n beta
eq "re-add value" "reborn" "$OUT"

# the store directory is created on demand
if [ ! -f "$D/records.tsv" ]; then
    echo "FAIL store file was not created at $D/records.tsv" >&2
    fails=$((fails + 1))
fi

exit $((fails > 0 ? 1 : 0))
