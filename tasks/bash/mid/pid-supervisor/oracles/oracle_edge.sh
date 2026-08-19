#!/usr/bin/env bash
# hidden - edge cases
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/svc.sh"
[ -f "$T" ] || { echo "missing svc.sh" >&2; exit 1; }

W="$(mktemp -d)"
STARTED=()
cleanup() {
    for p in ${STARTED[@]+"${STARTED[@]}"}; do
        kill -KILL "$p" 2>/dev/null
    done
    rm -rf "$W"
}
trap cleanup EXIT
fails=0
eq() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$2" "$3" >&2
    fails=$((fails + 1))
}
run() {
    bash "$T" "$@" > "$W/.out" 2> "$W/.err" < /dev/null
    RC=$?
    OUT="$(cat "$W/.out")"
    ERR="$(cat "$W/.err")"
}
alive() { kill -0 "$1" 2>/dev/null; }

cat > "$W/long.sh" <<'S'
#!/usr/bin/env bash
while :; do sleep 0.2; done
S
cat > "$W/stubborn.sh" <<'S'
#!/usr/bin/env bash
trap '' TERM
while :; do sleep 0.2; done
S

dead_pid() {
    bash -c 'exit 0' &
    local d=$!
    wait "$d" 2>/dev/null
    printf '%s' "$d"
}

# a stale pidfile
P="$W/stale.pid"
printf '%s\n' "$(dead_pid)" > "$P"
run status --pidfile "$P"
eq "stale status rc" 4 "$RC"
eq "stale status" "stale" "$OUT"
if [ ! -e "$P" ]; then
    echo "FAIL status removed a stale pidfile" >&2
    fails=$((fails + 1))
fi
run stop --pidfile "$P"
eq "stale stop rc" 0 "$RC"
eq "stale stop" "stale" "$OUT"
if [ -e "$P" ]; then
    echo "FAIL stop left a stale pidfile behind" >&2
    fails=$((fails + 1))
fi

# a pidfile that is not a number at all
G="$W/garbage.pid"
printf 'not-a-number\n' > "$G"
run status --pidfile "$G"
eq "garbage status rc" 4 "$RC"
eq "garbage status" "stale" "$OUT"

# starting over a stale pidfile replaces it
S1="$W/replace.pid"
printf '%s\n' "$(dead_pid)" > "$S1"
run start --pidfile "$S1" -- bash "$W/long.sh"
eq "start over stale rc" 0 "$RC"
pid="${OUT#started: }"
STARTED+=("$pid")
eq "start over stale stdout" "started: $pid" "$OUT"
eq "stale pidfile replaced" "$pid" "$(cat "$S1")"

# the default log path is the pidfile plus .log
if [ ! -e "$S1.log" ]; then
    echo "FAIL the default log file $S1.log was not created" >&2
    fails=$((fails + 1))
fi

# restart on a running service stops it first
run restart --pidfile "$S1" --kill-after 3 -- bash "$W/long.sh"
eq "restart rc" 0 "$RC"
newpid="$(printf '%s\n' "$OUT" | sed -n 's/^started: //p')"
STARTED+=("$newpid")
eq "restart stdout" "$(printf 'stopped: %s\nstarted: %s' "$pid" "$newpid")" "$OUT"
if alive "$pid"; then
    echo "FAIL the old process survived restart" >&2
    fails=$((fails + 1))
fi
if ! alive "$newpid"; then
    echo "FAIL the new process is not running after restart" >&2
    fails=$((fails + 1))
fi
run stop --pidfile "$S1" --kill-after 3
eq "cleanup stop rc" 0 "$RC"

# restart with nothing running prints only the start line
R="$W/restart.pid"
run restart --pidfile "$R" -- bash "$W/long.sh"
eq "cold restart rc" 0 "$RC"
rpid="${OUT#started: }"
STARTED+=("$rpid")
eq "cold restart stdout" "started: $rpid" "$OUT"
run stop --pidfile "$R" --kill-after 3
eq "cold restart cleanup rc" 0 "$RC"

# a process that ignores SIGTERM is killed
K="$W/stubborn.pid"
run start --pidfile "$K" -- bash "$W/stubborn.sh"
eq "stubborn start rc" 0 "$RC"
kpid="${OUT#started: }"
STARTED+=("$kpid")
sleep 0.3
run stop --pidfile "$K" --kill-after 1
eq "stubborn stop rc" 0 "$RC"
eq "stubborn stop stdout" "killed: $kpid" "$OUT"
if alive "$kpid"; then
    echo "FAIL the stubborn process survived" >&2
    fails=$((fails + 1))
fi
if [ -e "$K" ]; then
    echo "FAIL the pidfile survived the kill" >&2
    fails=$((fails + 1))
fi

# usage errors
run
eq "no action rc" 2 "$RC"
run frobnicate --pidfile "$W/x.pid"
eq "unknown action rc" 2 "$RC"
run status
eq "no --pidfile rc" 2 "$RC"
run start --pidfile "$W/x.pid"
eq "start without a command rc" 2 "$RC"
run start --pidfile "$W/x.pid" --
eq "start with an empty command rc" 2 "$RC"
run restart --pidfile "$W/x.pid"
eq "restart without a command rc" 2 "$RC"
run stop --pidfile "$W/x.pid" -- true
eq "stop with a command rc" 2 "$RC"
run status --pidfile "$W/x.pid" -- true
eq "status with a command rc" 2 "$RC"
run status --pidfile "$W/x.pid" --bogus
eq "unknown option rc" 2 "$RC"
run status --pidfile
eq "dangling --pidfile rc" 2 "$RC"
run stop --pidfile "$W/x.pid" --kill-after abc
eq "non-numeric --kill-after rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
