#!/usr/bin/env bash
# hidden - core behaviour: the new feature, and copying that actually works
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
tree_of() { find "$1" -mindepth 1 -printf '%y %P\n' | sort; }

S="$W/src"
mkdir -p "$S/assets" "$S/deep/nested dir"
printf 'index\n'  > "$S/index.html"
printf 'style\n'  > "$S/assets/main style.css"
printf 'logo\n'   > "$S/assets/logo.png"
printf 'deep\n'   > "$S/deep/nested dir/data file.json"
printf 'top\n'    > "$S/read me.txt"

# --- dry run ---------------------------------------------------------------

D1="$W/dest1"
ST1="$W/state1"
run --dry-run deploy --id r1 --src "$S" --dest "$D1" --state "$ST1"
eq "dry run rc" 0 "$RC"
eq "dry run stderr" "" "$ERR"
eq "dry run stdout" "$(printf 'DRY: copy assets/logo.png\nDRY: copy assets/main style.css\nDRY: copy deep/nested dir/data file.json\nDRY: copy index.html\nDRY: copy read me.txt\nDRY: record r1')" "$OUT"
eq "dry run created no destination" "no" "$([ -e "$D1" ] && echo yes || echo no)"
eq "dry run created no state" "no" "$([ -e "$ST1" ] && echo yes || echo no)"

run --dry-run deploy --id r1 --src "$S" --dest "$D1" --state "$ST1" --verify 'test -f index.html'
eq "dry run with verify rc" 0 "$RC"
eq "dry run with verify stdout" "$(printf 'DRY: copy assets/logo.png\nDRY: copy assets/main style.css\nDRY: copy deep/nested dir/data file.json\nDRY: copy index.html\nDRY: copy read me.txt\nDRY: verify\nDRY: record r1')" "$OUT"
eq "dry run with verify created nothing" "no" "$([ -e "$D1" ] && echo yes || echo no)"

# --- a real deployment ------------------------------------------------------

ST="$W/state"
run deploy --id r1 --src "$S" --dest "$W/dest" --state "$ST"
eq "deploy rc" 0 "$RC"
eq "deploy stderr" "" "$ERR"
eq "deploy stdout" "deployed: r1 (5 files)" "$OUT"
eq "deployed tree" "$(tree_of "$S")" "$(tree_of "$W/dest")"
eq "spaced file content" "style" "$(cat "$W/dest/assets/main style.css")"
eq "deep spaced file content" "deep" "$(cat "$W/dest/deep/nested dir/data file.json")"
eq "current.txt" "r1" "$(cat "$ST/current.txt")"
eq "history.tsv" "$(printf 'r1\t5')" "$(cat "$ST/history.tsv")"

# --- history ----------------------------------------------------------------

run deploy --id r2 --src "$S" --dest "$W/dest" --state "$ST"
eq "second deploy rc" 0 "$RC"
run deploy --id r3 --src "$S" --dest "$W/dest" --state "$ST"
eq "third deploy rc" 0 "$RC"
eq "current.txt after three" "r3" "$(cat "$ST/current.txt")"

run history --state "$ST"
eq "history rc" 0 "$RC"
eq "history" "$(printf 'r3\nr2\nr1')" "$OUT"

run history --state "$ST" --limit 2
eq "history limited rc" 0 "$RC"
eq "history limited" "$(printf 'r3\nr2')" "$OUT"

run history --state "$ST" --limit 1
eq "history limit one" "r3" "$OUT"

run history --state "$ST" --limit 99
eq "history limit beyond the end" "$(printf 'r3\nr2\nr1')" "$OUT"

run history --state "$W/never"
eq "history with no state rc" 0 "$RC"
eq "history with no state" "" "$OUT"

exit $((fails > 0 ? 1 : 0))
