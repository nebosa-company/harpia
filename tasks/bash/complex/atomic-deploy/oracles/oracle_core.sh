#!/usr/bin/env bash
# hidden - core behaviour
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
mkart() { # mkart <name> <version text>
    rm -rf "$W/build"
    mkdir -p "$W/build"
    printf '%s\n' "$2" > "$W/build/VERSION"
    printf 'the app\n' > "$W/build/app.txt"
    tar -cf "$W/$1.tar" -C "$W/build" .
}

mkart a1 v1
mkart a2 v2
mkart a3 v3

R="$W/site"

run --root "$R" list
eq "empty list rc" 0 "$RC"
eq "empty list" "" "$OUT"

run --root "$R" rollback
eq "empty rollback rc" 6 "$RC"
eq "empty rollback stderr" "nothing to roll back" "$ERR"

run --root "$R" release --id v1 --artifact "$W/a1.tar"
eq "first release rc" 0 "$RC"
eq "first release stdout" "released: v1" "$OUT"
eq "first release stderr" "" "$ERR"
eq "current is a symlink" "yes" "$([ -L "$R/current" ] && echo yes)"
eq "current target" "releases/v1" "$(readlink "$R/current")"
eq "current content" "v1" "$(cat "$R/current/VERSION")"
eq "release directory content" "v1" "$(cat "$R/releases/v1/VERSION")"

run --root "$R" release --id v2 --artifact "$W/a2.tar"
eq "second release rc" 0 "$RC"
eq "second release stdout" "released: v2" "$OUT"
eq "current after second" "releases/v2" "$(readlink "$R/current")"
eq "old release kept" "v1" "$(cat "$R/releases/v1/VERSION")"

run --root "$R" list
eq "list rc" 0 "$RC"
eq "list" "$(printf 'v1\nv2 *')" "$OUT"

run --root "$R" rollback
eq "rollback rc" 0 "$RC"
eq "rollback stdout" "rolled back to: v1" "$OUT"
eq "current after rollback" "releases/v1" "$(readlink "$R/current")"
eq "served content after rollback" "v1" "$(cat "$R/current/VERSION")"

run --root "$R" list
eq "list after rollback" "$(printf 'v1 *\nv2')" "$OUT"

run --root "$R" rollback
eq "rollback forward rc" 0 "$RC"
eq "rollback forward stdout" "rolled back to: v2" "$OUT"
eq "current after second rollback" "releases/v2" "$(readlink "$R/current")"

# a duplicate id changes nothing
run --root "$R" release --id v1 --artifact "$W/a3.tar"
eq "duplicate rc" 4 "$RC"
eq "duplicate stderr" "duplicate release: v1" "$ERR"
eq "duplicate left current alone" "releases/v2" "$(readlink "$R/current")"
eq "duplicate left the old release alone" "v1" "$(cat "$R/releases/v1/VERSION")"

# a missing artifact
run --root "$R" release --id v9 --artifact "$W/nope.tar"
eq "missing artifact rc" 1 "$RC"
eq "missing artifact stderr" "no such file: $W/nope.tar" "$ERR"
eq "missing artifact left no directory" "no" "$([ -e "$R/releases/v9" ] && echo yes || echo no)"

# a health check that passes
run --root "$R" release --id v3 --artifact "$W/a3.tar" --health 'test -f VERSION'
eq "health pass rc" 0 "$RC"
eq "health pass stdout" "released: v3" "$OUT"
eq "current after health pass" "releases/v3" "$(readlink "$R/current")"

# a health check that fails takes the release with it
run --root "$R" release --id v4 --artifact "$W/a1.tar" --health 'test -f NOT_THERE'
eq "health fail rc" 5 "$RC"
eq "health fail stderr" "health check failed: v4" "$ERR"
eq "health fail stdout" "" "$OUT"
eq "health fail removed the release" "no" "$([ -e "$R/releases/v4" ] && echo yes || echo no)"
eq "health fail left current alone" "releases/v3" "$(readlink "$R/current")"

run --root "$R" list
eq "list after health failure" "$(printf 'v1\nv2\nv3 *')" "$OUT"

exit $((fails > 0 ? 1 : 0))
