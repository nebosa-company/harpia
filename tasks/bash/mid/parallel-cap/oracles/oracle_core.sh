#!/usr/bin/env bash
# hidden - core behaviour
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
run() {
    OUT="$(bash "$T" "$@" 2>"$W/.err")"
    RC=$?
    ERR="$(cat "$W/.err")"
}

# a batch with comments, blanks and mixed exit statuses
{
    printf '# a comment\n'
    printf 'true\n'
    printf '\n'
    printf 'exit 3\n'
    printf '   \n'
    printf '   # indented comment\n'
    printf 'true\n'
    printf 'exit 7\n'
} > "$W/batch.txt"

run -j 4 "$W/batch.txt"
eq "mixed rc" 1 "$RC"
eq "mixed summary" "$(printf '2\t0\n4\t3\n7\t0\n8\t7\nok: 2 failed: 2')" "$OUT"

# every command succeeds
printf 'true\ntrue\ntrue\n' > "$W/allok.txt"
run -j 2 "$W/allok.txt"
eq "all ok rc" 0 "$RC"
eq "all ok summary" "$(printf '1\t0\n2\t0\n3\t0\nok: 3 failed: 0')" "$OUT"

# command output flows through untouched
printf 'printf "hello from the job\\n"\n' > "$W/one.txt"
run -j 1 "$W/one.txt"
eq "passthrough rc" 0 "$RC"
eq "passthrough" "$(printf 'hello from the job\n1\t0\nok: 1 failed: 0')" "$OUT"

# the commands really are shell commands
printf 'printf "a\\nb\\n" | grep -c b > %s/pipe.out\n' "$W" > "$W/shell.txt"
run -j 1 "$W/shell.txt"
eq "shell features rc" 0 "$RC"
eq "shell features" "1" "$(cat "$W/pipe.out")"

# N slots really are used at once: three jobs that each wait for the other two
cat > "$W/barrier.sh" <<'JOB'
#!/usr/bin/env bash
{
    flock 9
    c=$(cat "$CFILE"); c=$((c + 1)); printf '%s' "$c" > "$CFILE"
    m=$(cat "$MFILE"); if [ "$c" -gt "$m" ]; then printf '%s' "$c" > "$MFILE"; fi
} 9> "$LOCK"
for _ in $(seq 1 500); do
    [ "$(cat "$CFILE")" -ge "$WANT" ] && break
    sleep 0.01
done
{
    flock 9
    c=$(cat "$CFILE"); printf '%s' "$((c - 1))" > "$CFILE"
} 9> "$LOCK"
JOB
export CFILE="$W/count" MFILE="$W/max" LOCK="$W/lock" WANT=3
printf '0' > "$CFILE"
printf '0' > "$MFILE"
: > "$LOCK"
for _ in 1 2 3; do printf 'bash %s/barrier.sh\n' "$W"; done > "$W/par.txt"

run -j 3 "$W/par.txt"
eq "barrier rc" 0 "$RC"
eq "barrier summary" "$(printf '1\t0\n2\t0\n3\t0\nok: 3 failed: 0')" "$OUT"
eq "three ran at once" "3" "$(cat "$MFILE")"

exit $((fails > 0 ? 1 : 0))
