#!/usr/bin/env bash
# hidden - edge cases
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
mkart() {
    rm -rf "$W/build"
    mkdir -p "$W/build"
    printf '%s\n' "$2" > "$W/build/VERSION"
    tar -cf "$W/$1.tar" -C "$W/build" .
}

for v in 1 2 3 4 5; do mkart "a$v" "v$v"; done

# --keep prunes the oldest releases and never the current one
K="$W/keep"
for v in 1 2 3; do
    run --root "$K" release --id "r$v" --artifact "$W/a$v.tar"
    eq "keep setup r$v rc" 0 "$RC"
done
run --root "$K" release --id r4 --artifact "$W/a4.tar" --keep 2
eq "prune rc" 0 "$RC"
eq "prune stdout" "$(printf 'released: r4\npruned: r1\npruned: r2')" "$OUT"
run --root "$K" list
eq "list after prune" "$(printf 'r3\nr4 *')" "$OUT"

run --root "$K" release --id r5 --artifact "$W/a5.tar" --keep 1
eq "prune to one rc" 0 "$RC"
eq "prune to one stdout" "$(printf 'released: r5\npruned: r3\npruned: r4')" "$OUT"
run --root "$K" list
eq "list after pruning to one" "r5 *" "$OUT"
run --root "$K" rollback
eq "rollback with one release rc" 6 "$RC"
eq "rollback with one release stderr" "nothing to roll back" "$ERR"

# --keep larger than the number of releases removes nothing
run --root "$K" release --id r6 --artifact "$W/a1.tar" --keep 10
eq "generous keep stdout" "released: r6" "$OUT"

# a corrupt archive
printf 'this is not a tar archive at all\n' > "$W/broken.tar"
C="$W/corrupt"
run --root "$C" release --id ok1 --artifact "$W/a1.tar"
eq "corrupt setup rc" 0 "$RC"
run --root "$C" release --id bad1 --artifact "$W/broken.tar"
eq "corrupt rc" 3 "$RC"
eq "corrupt stderr" "extract failed: bad1" "$ERR"
eq "corrupt removed the release" "no" "$([ -e "$C/releases/bad1" ] && echo yes || echo no)"
eq "corrupt left current alone" "releases/ok1" "$(readlink "$C/current")"

# the health command runs inside the new release directory
H="$W/health"
run --root "$H" release --id h1 --artifact "$W/a3.tar" --health 'grep -q v3 VERSION'
eq "health cwd rc" 0 "$RC"
eq "health cwd stdout" "released: h1" "$OUT"
run --root "$H" release --id h2 --artifact "$W/a1.tar" --health 'grep -q v3 VERSION'
eq "health cwd fail rc" 5 "$RC"
eq "health cwd left current alone" "releases/h1" "$(readlink "$H/current")"

# current never disappears while a release is being made
A="$W/atomic"
run --root "$A" release --id s1 --artifact "$W/a1.tar"
eq "atomic setup rc" 0 "$RC"
BROKEN="$W/broken.log"
: > "$BROKEN"
(
    SECONDS=0
    while [ "$SECONDS" -lt 2 ]; do
        if [ ! -e "$A/current/VERSION" ]; then
            printf 'gap\n' >> "$BROKEN"
        fi
    done
) &
watcher=$!
sleep 0.2
run --root "$A" release --id s2 --artifact "$W/a2.tar"
eq "atomic release rc" 0 "$RC"
run --root "$A" release --id s3 --artifact "$W/a3.tar"
eq "atomic second release rc" 0 "$RC"
wait "$watcher"
eq "current never went missing" "" "$(cat "$BROKEN")"
eq "atomic final target" "releases/s3" "$(readlink "$A/current")"

# a tree with releases but no current symlink
N="$W/nocurrent"
mkdir -p "$N/releases/x1" "$N/releases/x2"
run --root "$N" list
eq "list without current rc" 0 "$RC"
eq "list without current" "$(printf 'x1\nx2')" "$OUT"
run --root "$N" rollback
eq "rollback without current rc" 6 "$RC"

# a trailing slash on the root is harmless
run --root "$N/" list
eq "trailing slash list" "$(printf 'x1\nx2')" "$OUT"

# usage errors
run release --id v1 --artifact "$W/a1.tar"
eq "no --root rc" 2 "$RC"
run --root "$W/u"
eq "no action rc" 2 "$RC"
run --root "$W/u" frobnicate
eq "unknown action rc" 2 "$RC"
run --root "$W/u" release --artifact "$W/a1.tar"
eq "release without --id rc" 2 "$RC"
run --root "$W/u" release --id v1
eq "release without --artifact rc" 2 "$RC"
run --root "$W/u" release --id 'bad id' --artifact "$W/a1.tar"
eq "id with a space rc" 2 "$RC"
run --root "$W/u" release --id 'a/b' --artifact "$W/a1.tar"
eq "id with a slash rc" 2 "$RC"
run --root "$W/u" release --id '' --artifact "$W/a1.tar"
eq "empty id rc" 2 "$RC"
run --root "$W/u" release --id v1 --artifact "$W/a1.tar" --keep 0
eq "zero keep rc" 2 "$RC"
run --root "$W/u" release --id v1 --artifact "$W/a1.tar" --keep x
eq "non-numeric keep rc" 2 "$RC"
run --root "$W/u" list extra
eq "two actions rc" 2 "$RC"
run --root "$W/u" --bogus list
eq "unknown option rc" 2 "$RC"
run --root
eq "dangling --root rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
