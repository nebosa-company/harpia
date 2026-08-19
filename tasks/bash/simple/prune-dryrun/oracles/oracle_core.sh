#!/usr/bin/env bash
# hidden - core behaviour
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
OLD=$((NOW - 200 * 86400))
mk() {
    mkdir -p "$(dirname -- "$1")"
    printf 'x' > "$1"
    touch -d "@$2" -- "$1"
}

build() {
    rm -rf "$1"
    mk "$1/old1.log" "$OLD"
    mk "$1/fresh.log" "$NOW"
    mk "$1/keep me.log" "$OLD"
    mk "$1/.git/old.log" "$OLD"
    mk "$1/node_modules/pkg/old.js" "$OLD"
    mk "$1/.cache/old.dat" "$OLD"
    mk "$1/sub/old2.log" "$OLD"
    mk "$1/sub/deep/old3.tmp" "$OLD"
    mk "$1/sub/fresh2.log" "$NOW"
    ln -s old2.log "$1/sub/link.log"
}

D="$W/tree"
build "$D"
before="$(tree_of "$D")"

want="$(printf 'keep me.log\nold1.log\nsub/deep/old3.tmp\nsub/old2.log\ncandidates: 4')"
run --root "$D" --older-than 30
eq "dry run rc" 0 "$RC"
eq "dry run output" "$want" "$OUT"
eq "dry run stderr" "" "$ERR"
eq "dry run changed nothing" "$before" "$(tree_of "$D")"

# a trailing slash on the root does not change the relative paths
run --root "$D/" --older-than 30
eq "trailing slash" "$want" "$OUT"

run --root "$D" --older-than 30 --exclude '*.tmp'
eq "one exclude" "$(printf 'keep me.log\nold1.log\nsub/old2.log\ncandidates: 3')" "$OUT"

run --root "$D" --older-than 30 --exclude '*.tmp' --exclude 'old1.*'
eq "two excludes" "$(printf 'keep me.log\nsub/old2.log\ncandidates: 2')" "$OUT"

run --root "$D" --older-than 100000
eq "nothing old enough" "candidates: 0" "$OUT"

# --apply prints the same list and removes exactly those files
run --root "$D" --older-than 30 --apply
eq "apply rc" 0 "$RC"
eq "apply output" "$want" "$OUT"
after="$(tree_of "$D")"
gone="$(printf 'd .cache\nd .git\nd node_modules\nd node_modules/pkg\nd sub\nd sub/deep\nf .cache/old.dat\nf .git/old.log\nf fresh.log\nf node_modules/pkg/old.js\nf sub/fresh2.log\nl sub/link.log' | sort)"
eq "apply removed exactly the candidates" "$gone" "$after"

exit $((fails > 0 ? 1 : 0))
