#!/usr/bin/env bash
# hidden - core behaviour
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/bashtap.sh"
[ -f "$T" ] || { echo "missing bashtap.sh" >&2; exit 1; }

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

mkdir -p "$W/t"

cat > "$W/t/basic_test.sh" <<'F'
test_addition_works() {
    assert_eq 4 "$((2 + 2))"
}

test_string_compare_fails() {
    assert_eq "hello" "goodbye"
}

test_custom_message() {
    assert_eq 1 2 "one is not two"
}

test_command_ok() {
    assert_ok true
}

test_command_should_fail() {
    assert_fail false
}
F

cat > "$W/t/flow_test.sh" <<'F'
test_skipped_one() {
    skip "not on this platform"
    assert_eq 1 2
}

test_todo_pending() {
    todo "not implemented yet"
    assert_eq 1 2
}

test_todo_passing() {
    todo "already works"
    assert_eq 1 1
}

test_returns_nonzero() {
    false
}

test_exits_hard() {
    exit 7
}

test_after_exit() {
    assert_eq ok ok
}
F

want="$(cat <<'EXP'
TAP version 13
1..11
ok 1 - addition works
not ok 2 - string compare fails
# expected [hello] but got [goodbye]
not ok 3 - custom message
# one is not two
ok 4 - command ok
ok 5 - command should fail
ok 6 - skipped one # SKIP not on this platform
not ok 7 - todo pending # TODO not implemented yet
# expected [1] but got [2]
ok 8 - todo passing # TODO already works
not ok 9 - returns nonzero
# test returned 1
not ok 10 - exits hard
# test returned 7
ok 11 - after exit
EXP
)"

run "$W/t/basic_test.sh" "$W/t/flow_test.sh"
eq "mixed run stdout" "$want" "$OUT"
eq "mixed run rc" 1 "$RC"
eq "mixed run stderr" "" "$ERR"

# --verbose interleaves a line naming each file
vwant="$(printf 'TAP version 13
1..11
# running %s
ok 1 - addition works
not ok 2 - string compare fails
# expected [hello] but got [goodbye]
not ok 3 - custom message
# one is not two
ok 4 - command ok
ok 5 - command should fail
# running %s
ok 6 - skipped one # SKIP not on this platform
not ok 7 - todo pending # TODO not implemented yet
# expected [1] but got [2]
ok 8 - todo passing # TODO already works
not ok 9 - returns nonzero
# test returned 1
not ok 10 - exits hard
# test returned 7
ok 11 - after exit
' "$W/t/basic_test.sh" "$W/t/flow_test.sh")"
run --verbose "$W/t/basic_test.sh" "$W/t/flow_test.sh"
eq "verbose run stdout" "$vwant" "$OUT"
eq "verbose run rc" 1 "$RC"

# a run where everything passes
cat > "$W/t/happy_test.sh" <<'F'
test_one() {
    assert_eq a a
}
test_two() {
    assert_ok true
    assert_fail false
}
F
run "$W/t/happy_test.sh"
eq "happy rc" 0 "$RC"
eq "happy stdout" "$(printf 'TAP version 13\n1..2\nok 1 - one\nok 2 - two')" "$OUT"

# bail stops the run where it stands
cat > "$W/t/bail_test.sh" <<'F'
test_first_ok() {
    assert_eq 1 1
}

test_pulls_the_cord() {
    bail "environment is broken"
}

test_never_runs() {
    assert_eq 1 1
}
F
run "$W/t/bail_test.sh"
eq "bail rc" 4 "$RC"
eq "bail stdout" "$(printf 'TAP version 13\n1..3\nok 1 - first ok\nnot ok 2 - pulls the cord\n# environment is broken\nBail out! environment is broken')" "$OUT"

# a bail in the first file stops the second file too
run "$W/t/bail_test.sh" "$W/t/happy_test.sh"
eq "bail across files rc" 4 "$RC"
eq "bail across files stdout" "$(printf 'TAP version 13\n1..5\nok 1 - first ok\nnot ok 2 - pulls the cord\n# environment is broken\nBail out! environment is broken')" "$OUT"

exit $((fails > 0 ? 1 : 0))
