#!/usr/bin/env bash
# hidden - edge cases
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/sweep.sh"
[ -f "$T" ] || { echo "missing sweep.sh" >&2; exit 1; }

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
tree_of() { find "$1" -mindepth 1 -printf '%y %P\n' | sort; }

NOW="$(date +%s)"
OLD=$((NOW - 400 * 86400))
mk() {
    mkdir -p "$(dirname -- "$1")"
    printf 'x' > "$1"
    touch -d "@$2" -- "$1"
}

D="$W/tree"
mk "$D/old1.log" "$OLD"
mk "$D/old2.log" "$OLD"
mk "$D/report.csv" "$OLD"
mk "$D/a/old3.log" "$OLD"
mk "$D/a/alpha.log" "$OLD"

run --root "$D" --older-than 1
eq "baseline" "$(printf 'a/alpha.log\na/old3.log\nold1.log\nold2.log\nreport.csv\ncandidates: 5')" "$OUT"

# glob metacharacters in --exclude behave like shell patterns
run --root "$D" --older-than 1 --exclude 'old?.log'
eq "question glob" "$(printf 'a/alpha.log\nreport.csv\ncandidates: 2')" "$OUT"

run --root "$D" --older-than 1 --exclude 'old[12].log'
eq "bracket glob" "$(printf 'a/alpha.log\na/old3.log\nreport.csv\ncandidates: 3')" "$OUT"

# globs match the base name, never the directory part
run --root "$D" --older-than 1 --exclude 'a*'
eq "base name only" "$(printf 'a/old3.log\nold1.log\nold2.log\nreport.csv\ncandidates: 4')" "$OUT"

# --older-than 0 keeps everything strictly older than now
run --root "$D" --older-than 0
eq "zero days" "$(printf 'a/alpha.log\na/old3.log\nold1.log\nold2.log\nreport.csv\ncandidates: 5')" "$OUT"

# an empty tree
E="$W/empty"
mkdir -p "$E"
run --root "$E" --older-than 1
eq "empty rc" 0 "$RC"
eq "empty" "candidates: 0" "$OUT"

# a tree holding nothing but pruned directories
P="$W/pruned"
mk "$P/.git/objects/pack.idx" "$OLD"
mk "$P/node_modules/dep/index.js" "$OLD"
mk "$P/.cache/blob" "$OLD"
pbefore="$(tree_of "$P")"
run --root "$P" --older-than 1 --apply
eq "pruned only rc" 0 "$RC"
eq "pruned only" "candidates: 0" "$OUT"
eq "pruned dirs untouched" "$pbefore" "$(tree_of "$P")"

# missing or non-directory root
run --root "$W/nope" --older-than 1
eq "missing root rc" 1 "$RC"
eq "missing root stderr" "not a directory: $W/nope" "$ERR"

printf 'x' > "$W/plainfile"
run --root "$W/plainfile" --older-than 1
eq "file as root rc" 1 "$RC"

# usage errors
run --older-than 1
eq "no --root rc" 2 "$RC"
run --root "$D"
eq "no --older-than rc" 2 "$RC"
run --root "$D" --older-than -5
eq "negative days rc" 2 "$RC"
run --root "$D" --older-than 1.5
eq "fractional days rc" 2 "$RC"
run --root "$D" --older-than abc
eq "non-numeric days rc" 2 "$RC"
run --root "$D" --older-than 1 --bogus
eq "unknown option rc" 2 "$RC"
run --root "$D" --older-than 1 --exclude
eq "dangling --exclude rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
