#!/usr/bin/env bash
# hidden - edge cases
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

mkdir -p "$W/bin"
cat > "$W/bin/sleep" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$SLEEP_LOG"
STUB
chmod +x "$W/bin/sleep"
export PATH="$W/bin:$PATH"
export SLEEP_LOG="$W/sleeps.txt"

printf '#!/usr/bin/env bash\nexit "$FAIL_CODE"\n' > "$W/always.sh"
export FAIL_CODE=1

run() {
    : > "$SLEEP_LOG"
    OUT="$(bash "$T" "$@" 2>"$W/.err")"
    RC=$?
    ERR="$(cat "$W/.err")"
    SLEPT="$(paste -sd' ' "$SLEEP_LOG")"
}

# the delay doubles and is then held at the cap
run --attempts 6 --base-delay 1 --max-delay 4 -- bash "$W/always.sh"
eq "capped rc" 1 "$RC"
eq "capped delays" "1 2 4 4 4" "$SLEPT"

# a base delay already above the cap is capped from the first wait
run --attempts 3 --base-delay 10 --max-delay 2 -- bash "$W/always.sh"
eq "cap below base" "2 2" "$SLEPT"

# a zero base delay still calls sleep, with zero
run --attempts 3 --base-delay 0 -- bash "$W/always.sh"
eq "zero base delays" "0 0" "$SLEPT"

# without a cap the delay keeps doubling
run --attempts 5 --base-delay 3 -- bash "$W/always.sh"
eq "uncapped delays" "3 6 12 24" "$SLEPT"

# an unusual exit status is reported and returned verbatim
export FAIL_CODE=42
run --attempts 2 --base-delay 1 -- bash "$W/always.sh"
eq "status 42 rc" 42 "$RC"
eq "status 42 report" "$(printf 'attempt 1/2 failed with 42\nattempt 2/2 failed with 42')" "$ERR"

# a command that cannot be executed fails like any other
run --attempts 2 --base-delay 1 -- "$W/no-such-program-here"
eq "missing program rc" 127 "$RC"
eq "missing program delays" "1" "$SLEPT"

# usage errors
run --attempts 3 --base-delay 1 bash "$W/always.sh"
eq "missing separator rc" 2 "$RC"
run --attempts 3 --base-delay 1 --
eq "nothing after separator rc" 2 "$RC"
run --base-delay 1 -- bash "$W/always.sh"
eq "no --attempts rc" 2 "$RC"
run --attempts 3 -- bash "$W/always.sh"
eq "no --base-delay rc" 2 "$RC"
run --attempts 0 --base-delay 1 -- bash "$W/always.sh"
eq "zero attempts rc" 2 "$RC"
run --attempts abc --base-delay 1 -- bash "$W/always.sh"
eq "non-numeric attempts rc" 2 "$RC"
run --attempts 3 --base-delay -1 -- bash "$W/always.sh"
eq "negative base rc" 2 "$RC"
run --attempts 3 --base-delay 1 --max-delay x -- bash "$W/always.sh"
eq "non-numeric cap rc" 2 "$RC"
run --attempts 3 --base-delay 1 --bogus -- bash "$W/always.sh"
eq "unknown option rc" 2 "$RC"
run --attempts
eq "dangling option rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
