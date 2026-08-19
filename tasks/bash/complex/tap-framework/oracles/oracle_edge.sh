#!/usr/bin/env bash
# hidden - edge cases
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

# default diagnostics for the command assertions
cat > "$W/t/cmd_test.sh" <<'F'
test_ok_default_message() {
    assert_ok test 1 -eq 2
}
test_fail_default_message() {
    assert_fail test 1 -eq 1
}
F
run "$W/t/cmd_test.sh"
eq "command diagnostics rc" 1 "$RC"
eq "command diagnostics" "$(printf 'TAP version 13\n1..2\nnot ok 1 - ok default message\n# command failed: test 1 -eq 2\nnot ok 2 - fail default message\n# command unexpectedly succeeded: test 1 -eq 1')" "$OUT"

# several failed assertions in one test are all reported, in order
cat > "$W/t/multi_test.sh" <<'F'
test_three_failures() {
    assert_eq a b
    assert_eq c d "third message"
    assert_ok false
    return 0
}
F
run "$W/t/multi_test.sh"
eq "multiple diagnostics rc" 1 "$RC"
eq "multiple diagnostics" "$(printf 'TAP version 13\n1..1\nnot ok 1 - three failures\n# expected [a] but got [b]\n# third message\n# command failed: false')" "$OUT"

# a failed assertion suppresses the "test returned" diagnostic
cat > "$W/t/both_test.sh" <<'F'
test_fails_and_returns() {
    assert_eq a b
}
F
run "$W/t/both_test.sh"
eq "no duplicate diagnostic" "$(printf 'TAP version 13\n1..1\nnot ok 1 - fails and returns\n# expected [a] but got [b]')" "$OUT"

# the `function` keyword form is recognised, and declaration order wins
cat > "$W/t/order_test.sh" <<'F'
function test_zulu() {
    assert_eq 1 1
}
  test_alpha() {
    assert_eq 1 1
}
test_mike () {
    assert_eq 1 1
}
F
run "$W/t/order_test.sh"
eq "declaration order rc" 0 "$RC"
eq "declaration order" "$(printf 'TAP version 13\n1..3\nok 1 - zulu\nok 2 - alpha\nok 3 - mike')" "$OUT"

# a file with no tests contributes nothing but is still announced
cat > "$W/t/empty_test.sh" <<'F'
helper_not_a_test() {
    :
}
F
run "$W/t/empty_test.sh"
eq "no tests rc" 0 "$RC"
eq "no tests" "$(printf 'TAP version 13\n1..0')" "$OUT"

run --verbose "$W/t/empty_test.sh" "$W/t/both_test.sh"
eq "verbose with an empty file" "$(printf 'TAP version 13\n1..1\n# running %s\n# running %s\nnot ok 1 - fails and returns\n# expected [a] but got [b]' "$W/t/empty_test.sh" "$W/t/both_test.sh")" "$OUT"

# tests are isolated from one another, and top-level code runs once per test
cat > "$W/t/iso_test.sh" <<'F'
printf 'x' >> "$MARKER"
counter=0

test_first_bumps() {
    counter=$((counter + 1))
    assert_eq 1 "$counter"
}

test_second_sees_fresh() {
    assert_eq 0 "$counter"
}
F
export MARKER="$W/marker"
: > "$MARKER"
run "$W/t/iso_test.sh"
eq "isolation rc" 0 "$RC"
eq "isolation" "$(printf 'TAP version 13\n1..2\nok 1 - first bumps\nok 2 - second sees fresh')" "$OUT"
eq "sourced once per test" "xx" "$(cat "$MARKER")"

# whatever a test prints never reaches the TAP stream
cat > "$W/t/noisy_test.sh" <<'F'
test_chatty() {
    echo "not ok 99 - forged"
    echo "1..999" >&2
    assert_eq 1 1
}
F
run "$W/t/noisy_test.sh"
eq "noise discarded rc" 0 "$RC"
eq "noise discarded" "$(printf 'TAP version 13\n1..1\nok 1 - chatty')" "$OUT"
eq "noise not on stderr" "" "$ERR"

# a run of nothing but skips and failing TODOs still succeeds
cat > "$W/t/soft_test.sh" <<'F'
test_one() {
    skip "no reason"
}
test_two() {
    todo "later"
    assert_eq 1 2
}
F
run "$W/t/soft_test.sh"
eq "soft rc" 0 "$RC"
eq "soft" "$(printf 'TAP version 13\n1..2\nok 1 - one # SKIP no reason\nnot ok 2 - two # TODO later\n# expected [1] but got [2]')" "$OUT"

# unreadable files are reported before any TAP output
run "$W/t/absent_test.sh"
eq "missing file rc" 3 "$RC"
eq "missing file stderr" "cannot read: $W/t/absent_test.sh" "$ERR"
eq "missing file stdout" "" "$OUT"

run "$W/t/soft_test.sh" "$W/t/absent_test.sh"
eq "missing second file rc" 3 "$RC"
eq "missing second file stdout" "" "$OUT"

# usage errors
run
eq "no files rc" 2 "$RC"
run --verbose
eq "verbose with no files rc" 2 "$RC"
run --bogus "$W/t/soft_test.sh"
eq "unknown option rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
