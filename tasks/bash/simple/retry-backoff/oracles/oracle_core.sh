#!/usr/bin/env bash
# hidden - core behaviour
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/retry.sh"
[ -f "$T" ] || { echo "missing retry.sh" >&2; exit 1; }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
fails=0
eq() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$2" "$3" >&2
    fails=$((fails + 1))
}

# A stand-in for sleep that records the requested delay and returns at once.
mkdir -p "$W/bin"
cat > "$W/bin/sleep" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$SLEEP_LOG"
STUB
chmod +x "$W/bin/sleep"
export PATH="$W/bin:$PATH"
export SLEEP_LOG="$W/sleeps.txt"

cat > "$W/flaky.sh" <<'CMD'
#!/usr/bin/env bash
n=$(cat "$COUNTER")
n=$((n + 1))
printf '%s' "$n" > "$COUNTER"
printf 'run %s\n' "$n"
if [ "$n" -le "$FAIL_TIMES" ]; then
    printf 'boom %s\n' "$n" >&2
    exit "$FAIL_CODE"
fi
exit 0
CMD
export COUNTER="$W/counter"

run() {
    : > "$SLEEP_LOG"
    printf '0' > "$COUNTER"
    OUT="$(bash "$T" "$@" 2>"$W/.err")"
    RC=$?
    ERR="$(cat "$W/.err")"
    SLEPT="$(paste -sd' ' "$SLEEP_LOG")"
}

# succeeds on the first attempt: no waiting, nothing on stderr
export FAIL_TIMES=0 FAIL_CODE=9
run --attempts 5 --base-delay 1 -- bash "$W/flaky.sh"
eq "first try rc" 0 "$RC"
eq "first try stdout" "run 1" "$OUT"
eq "first try stderr" "" "$ERR"
eq "first try slept" "" "$SLEPT"

# two failures then a success
export FAIL_TIMES=2 FAIL_CODE=4
run --attempts 5 --base-delay 1 -- bash "$W/flaky.sh"
eq "flaky rc" 0 "$RC"
eq "flaky stdout" "$(printf 'run 1\nrun 2\nrun 3')" "$OUT"
eq "flaky delays" "1 2" "$SLEPT"
eq "flaky stderr" "$(printf 'boom 1\nattempt 1/5 failed with 4\nboom 2\nattempt 2/5 failed with 4')" "$ERR"

# never succeeds: exit status is the command's own
export FAIL_TIMES=99 FAIL_CODE=7
run --attempts 3 --base-delay 2 -- bash "$W/flaky.sh"
eq "always fails rc" 7 "$RC"
eq "always fails stdout" "$(printf 'run 1\nrun 2\nrun 3')" "$OUT"
eq "always fails delays" "2 4" "$SLEPT"
eq "always fails attempts" "$(printf 'attempt 1/3 failed with 7\nattempt 2/3 failed with 7\nattempt 3/3 failed with 7')" "$(grep '^attempt ' "$W/.err")"

# a single attempt never waits
run --attempts 1 --base-delay 3 -- bash "$W/flaky.sh"
eq "one attempt rc" 7 "$RC"
eq "one attempt stdout" "run 1" "$OUT"
eq "one attempt delays" "" "$SLEPT"

# arguments reach the command untouched
cat > "$W/echoargs.sh" <<'CMD'
#!/usr/bin/env bash
for a in "$@"; do printf '[%s]' "$a"; done
printf '\n'
CMD
export FAIL_TIMES=0
run --attempts 2 --base-delay 1 -- bash "$W/echoargs.sh" 'two words' '--attempts' '*'
eq "argument passthrough rc" 0 "$RC"
eq "argument passthrough" "[two words][--attempts][*]" "$OUT"

exit $((fails > 0 ? 1 : 0))
