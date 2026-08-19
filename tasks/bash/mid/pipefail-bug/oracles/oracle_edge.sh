#!/usr/bin/env bash
# hidden - edge cases
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/report.sh"
[ -f "$T" ] || { echo "missing report.sh" >&2; exit 1; }

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
runpre() {
    local pre="$1"
    shift
    OUT="$(PREPROCESS="$pre" bash "$T" "$@" 2>"$W/.err")"
    RC=$?
    ERR="$(cat "$W/.err")"
}

printf 'zulu\nalpha\nmike\n' > "$W/in.txt"

cat > "$W/pre_ok.sh" <<'P'
#!/usr/bin/env bash
tr 'a-z' 'A-Z' < "$1"
P
cat > "$W/pre_fail.sh" <<'P'
#!/usr/bin/env bash
printf 'one\ntwo\nthree\n'
exit 42
P
cat > "$W/pre_fail1.sh" <<'P'
#!/usr/bin/env bash
printf 'partial\n'
exit 1
P

# a preprocessor that succeeds replaces cat
runpre "$W/pre_ok.sh" "$W/in.txt" "$W/o1"
eq "preprocessor rc" 0 "$RC"
eq "preprocessor stdout" "records: 3" "$OUT"
eq "preprocessor records" "$(printf 'ALPHA\nMIKE\nZULU')" "$(cat "$W/o1/records.txt")"

# a preprocessor that fails: the status is propagated, nothing is rejected
runpre "$W/pre_fail.sh" "$W/in.txt" "$W/o2"
eq "failing preprocessor rc" 42 "$RC"
eq "failing preprocessor stdout" "records: 3" "$OUT"
eq "failing preprocessor stderr" "" "$ERR"
eq "failing preprocessor records" "$(printf 'one\nthree\ntwo')" "$(cat "$W/o2/records.txt")"
if [ -e "$W/o2/rejects.txt" ]; then
    echo "FAIL rejects.txt written despite a failing preprocessor" >&2
    fails=$((fails + 1))
fi

runpre "$W/pre_fail1.sh" "$W/in.txt" "$W/o3"
eq "status 1 propagated" 1 "$RC"
eq "status 1 records" "records: 1" "$OUT"

# a preprocessor whose output would be rejected still reports its own status
cat > "$W/pre_bad.sh" <<'P'
#!/usr/bin/env bash
printf 'has a space\n'
exit 9
P
runpre "$W/pre_bad.sh" "$W/in.txt" "$W/o4"
eq "bad output failing preprocessor rc" 9 "$RC"
eq "bad output failing preprocessor stderr" "" "$ERR"

# an empty PREPROCESS falls back to cat
runpre "" "$W/in.txt" "$W/o5"
eq "empty preprocessor rc" 0 "$RC"
eq "empty preprocessor records" "$(printf 'alpha\nmike\nzulu')" "$(cat "$W/o5/records.txt")"

# an empty input, and one that is nothing but noise
: > "$W/empty.txt"
run "$W/empty.txt" "$W/o6"
eq "empty input rc" 0 "$RC"
eq "empty input stdout" "records: 0" "$OUT"
eq "empty input records" "" "$(cat "$W/o6/records.txt")"
if [ -e "$W/o6/rejects.txt" ]; then
    echo "FAIL rejects.txt created for an empty input" >&2
    fails=$((fails + 1))
fi

printf '# just\n\n   \n# comments\n' > "$W/noise.txt"
run "$W/noise.txt" "$W/o7"
eq "noise rc" 0 "$RC"
eq "noise stdout" "records: 0" "$OUT"

# every character class at the edge of the acceptable pattern
printf -- '-\n.\n_\nA9\na.b-c_d\n' > "$W/ok.txt"
run "$W/ok.txt" "$W/o8"
eq "boundary acceptable rc" 0 "$RC"
eq "boundary acceptable stdout" "records: 5" "$OUT"

printf 'a b\na\tb\na|b\na*b\n' > "$W/bad.txt"
run "$W/bad.txt" "$W/o9"
eq "boundary rejected rc" 3 "$RC"
eq "boundary rejected stderr" "rejected: 4" "$ERR"

# missing input and bad argument counts
run "$W/nope.txt" "$W/o10"
eq "missing input rc" 1 "$RC"
eq "missing input stderr" "input not found: $W/nope.txt" "$ERR"

run
eq "no args rc" 2 "$RC"
run "$W/in.txt"
eq "one arg rc" 2 "$RC"
run "$W/in.txt" "$W/o11" extra
eq "three args rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
