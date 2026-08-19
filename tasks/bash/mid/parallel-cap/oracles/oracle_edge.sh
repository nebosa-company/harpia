#!/usr/bin/env bash
# hidden - edge cases
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/prun.sh"
[ -f "$T" ] || { echo "missing prun.sh" >&2; exit 1; }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
fails=0
eq() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$2" "$3" >&2
    fails=$((fails + 1))
}
le() {
    if [ "$3" -le "$2" ]; then return 0; fi
    printf 'FAIL %s: %s exceeds the limit %s\n' "$1" "$3" "$2" >&2
    fails=$((fails + 1))
}
run() {
    OUT="$(bash "$T" "$@" 2>"$W/.err")"
    RC=$?
    ERR="$(cat "$W/.err")"
}

# the cap holds when there is far more work than there are slots
cat > "$W/slot.sh" <<'JOB'
#!/usr/bin/env bash
{
    flock 9
    c=$(cat "$CFILE"); c=$((c + 1)); printf '%s' "$c" > "$CFILE"
    m=$(cat "$MFILE"); if [ "$c" -gt "$m" ]; then printf '%s' "$c" > "$MFILE"; fi
} 9> "$LOCK"
sleep 0.4
{
    flock 9
    c=$(cat "$CFILE"); printf '%s' "$((c - 1))" > "$CFILE"
} 9> "$LOCK"
JOB
export CFILE="$W/count" MFILE="$W/max" LOCK="$W/lock"
printf '0' > "$CFILE"; printf '0' > "$MFILE"; : > "$LOCK"
for _ in 1 2 3 4 5 6; do printf 'bash %s/slot.sh\n' "$W"; done > "$W/six.txt"

run -j 2 "$W/six.txt"
eq "six jobs rc" 0 "$RC"
eq "six jobs summary" "$(printf '1\t0\n2\t0\n3\t0\n4\t0\n5\t0\n6\t0\nok: 6 failed: 0')" "$OUT"
le "concurrency cap" 2 "$(cat "$MFILE")"
eq "both slots were used" "2" "$(cat "$MFILE")"

# -j 1 runs the commands strictly in file order
: > "$W/order.txt"
{
    printf 'printf a >> %s/seq.out\n' "$W"
    printf 'printf b >> %s/seq.out\n' "$W"
    printf 'printf c >> %s/seq.out\n' "$W"
    printf 'printf d >> %s/seq.out\n' "$W"
} > "$W/order.txt"
: > "$W/seq.out"
run -j 1 "$W/order.txt"
eq "serial rc" 0 "$RC"
eq "serial order" "abcd" "$(cat "$W/seq.out")"

# nothing to run
printf '# only a comment\n\n   \n' > "$W/nothing.txt"
run -j 4 "$W/nothing.txt"
eq "nothing rc" 0 "$RC"
eq "nothing summary" "ok: 0 failed: 0" "$OUT"

: > "$W/blank.txt"
run -j 4 "$W/blank.txt"
eq "empty file rc" 0 "$RC"
eq "empty file summary" "ok: 0 failed: 0" "$OUT"

# unusual exit statuses survive
printf 'exit 42\nexit 127\ntrue\n' > "$W/codes.txt"
run -j 3 "$W/codes.txt"
eq "codes rc" 1 "$RC"
eq "codes summary" "$(printf '1\t42\n2\t127\n3\t0\nok: 1 failed: 2')" "$OUT"

# a line without a trailing newline still counts
printf 'true\nexit 5' > "$W/nonl.txt"
run -j 2 "$W/nonl.txt"
eq "no trailing newline rc" 1 "$RC"
eq "no trailing newline summary" "$(printf '1\t0\n2\t5\nok: 1 failed: 1')" "$OUT"

# quoting inside a command line is the shell's business, not the runner's
printf 'printf "%%s\\n" "two words" > %s/q.out\n' "$W" > "$W/quote.txt"
run -j 1 "$W/quote.txt"
eq "quoted command rc" 0 "$RC"
eq "quoted command" "two words" "$(cat "$W/q.out")"

# a command that does not exist fails like any other
printf '%s/definitely-not-here\n' "$W" > "$W/missing.txt"
run -j 1 "$W/missing.txt"
eq "missing program rc" 1 "$RC"
eq "missing program summary" "$(printf '1\t127\nok: 0 failed: 1')" "$OUT"

# file and usage errors
run -j 2 "$W/absent.txt"
eq "missing file rc" 1 "$RC"
eq "missing file stderr" "no such file: $W/absent.txt" "$ERR"

run "$W/allok.txt"
eq "no -j rc" 2 "$RC"
run -j 0 "$W/order.txt"
eq "zero jobs rc" 2 "$RC"
run -j -1 "$W/order.txt"
eq "negative jobs rc" 2 "$RC"
run -j abc "$W/order.txt"
eq "non-numeric jobs rc" 2 "$RC"
run -j 2
eq "no file rc" 2 "$RC"
run -j
eq "dangling -j rc" 2 "$RC"
run -x 2 "$W/order.txt"
eq "unknown option rc" 2 "$RC"
run -j 2 "$W/order.txt" "$W/six.txt"
eq "two files rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
