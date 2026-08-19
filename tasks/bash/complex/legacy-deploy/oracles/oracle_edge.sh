#!/usr/bin/env bash
# hidden - edge cases: the three faults, at their sharpest
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/deploy.sh"
[ -f "$T" ] || { echo "missing deploy.sh" >&2; exit 1; }

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

S="$W/src"
mkdir -p "$S/sub dir"
printf 'a\n' > "$S/plain.txt"
printf 'b\n' > "$S/two words.txt"
printf 'c\n' > "$S/sub dir/inner file.txt"

# a failing verification must not be reported as success
ST="$W/state"
run deploy --id v1 --src "$S" --dest "$W/dest1" --state "$ST"
eq "baseline rc" 0 "$RC"
eq "baseline stdout" "deployed: v1 (3 files)" "$OUT"
before_hist="$(cat "$ST/history.tsv")"
before_cur="$(cat "$ST/current.txt")"

run deploy --id v2 --src "$S" --dest "$W/dest2" --state "$ST" --verify 'test -f NOT_THERE'
eq "verify failure rc" 5 "$RC"
eq "verify failure stderr" "verify failed" "$ERR"
eq "verify failure stdout" "" "$OUT"
eq "history untouched" "$before_hist" "$(cat "$ST/history.tsv")"
eq "current untouched" "$before_cur" "$(cat "$ST/current.txt")"

run deploy --id v3 --src "$S" --dest "$W/dest3" --state "$ST" --verify 'exit 9'
eq "verify exit 9 rc" 5 "$RC"
eq "verify exit 9 history untouched" "$before_hist" "$(cat "$ST/history.tsv")"

# a verification that passes goes through, and runs inside the destination
run deploy --id v4 --src "$S" --dest "$W/dest4" --state "$ST" --verify 'test -f "two words.txt"'
eq "verify pass rc" 0 "$RC"
eq "verify pass stdout" "deployed: v4 (3 files)" "$OUT"
eq "verify pass recorded" "v4" "$(cat "$ST/current.txt")"
eq "verify pass history" "$(printf 'v1\t3\nv4\t3')" "$(cat "$ST/history.tsv")"

# eight deployments at once lose nothing and leave one clean pointer
CS="$W/cstate"
mkdir -p "$W/csrc"
printf 'x\n' > "$W/csrc/f.txt"
for i in 1 2 3 4 5 6 7 8; do
    bash "$T" deploy --id "c$i" --src "$W/csrc" --dest "$W/cdest$i" --state "$CS" > /dev/null 2>&1 &
done
wait
eq "history keeps every entry" "8" "$(wc -l < "$CS/history.tsv")"
eq "history entries are distinct" "8" "$(cut -f1 "$CS/history.tsv" | sort -u | wc -l)"
eq "current.txt is one line" "1" "$(wc -l < "$CS/current.txt")"
cur="$(cat "$CS/current.txt")"
case "$cur" in
    c[1-8]) ;;
    *) printf 'FAIL current.txt holds [%s]\n' "$cur" >&2; fails=$((fails + 1)) ;;
esac

# an empty source tree
mkdir -p "$W/emptysrc"
run deploy --id e1 --src "$W/emptysrc" --dest "$W/edest" --state "$W/estate"
eq "empty source rc" 0 "$RC"
eq "empty source stdout" "deployed: e1 (0 files)" "$OUT"
eq "empty source history" "$(printf 'e1\t0')" "$(cat "$W/estate/history.tsv")"

# a single file still says "files"
mkdir -p "$W/onesrc"
printf 'only\n' > "$W/onesrc/one.txt"
run deploy --id o1 --src "$W/onesrc" --dest "$W/odest" --state "$W/ostate"
eq "one file stdout" "deployed: o1 (1 files)" "$OUT"

# the state directory from config/app.conf is used when --state is absent,
# and the script works from any working directory
mkdir -p "$W/proj"
( cd "$W/proj" && bash "$T" deploy --id p1 --src "$S" --dest "$W/pdest" > "$W/.out" 2> "$W/.err" )
prc=$?
eq "config default rc" 0 "$prc"
eq "config default stdout" "deployed: p1 (3 files)" "$(cat "$W/.out")"
eq "config default state dir" "p1" "$(cat "$W/proj/state/current.txt" 2>/dev/null)"

# a missing source
run deploy --id x1 --src "$W/absent" --dest "$W/xdest" --state "$W/xstate"
eq "missing source rc" 1 "$RC"
eq "missing source stderr" "no such directory: $W/absent" "$ERR"
run --dry-run deploy --id x1 --src "$W/absent" --dest "$W/xdest" --state "$W/xstate"
eq "dry run missing source rc" 1 "$RC"

# usage errors
run
eq "no action rc" 2 "$RC"
run frobnicate
eq "unknown action rc" 2 "$RC"
run deploy --src "$S" --dest "$W/u"
eq "deploy without --id rc" 2 "$RC"
run deploy --id z1 --dest "$W/u"
eq "deploy without --src rc" 2 "$RC"
run deploy --id z1 --src "$S"
eq "deploy without --dest rc" 2 "$RC"
run deploy --id z1 --src "$S" --dest "$W/u" --bogus
eq "unknown option rc" 2 "$RC"
run deploy --id
eq "dangling --id rc" 2 "$RC"
run history --state "$ST" --limit 0
eq "zero limit rc" 2 "$RC"
run history --state "$ST" --limit abc
eq "non-numeric limit rc" 2 "$RC"
run deploy extra --id z1 --src "$S" --dest "$W/u"
eq "second positional rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
