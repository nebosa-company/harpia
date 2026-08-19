#!/usr/bin/env bash
# hidden - core behaviour
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
printf 'started %s\n' "$$"
while :; do sleep 0.2; done
S

P="$W/svc.pid"
L="$W/svc.log"

run status --pidfile "$P"
eq "status with no pidfile rc" 3 "$RC"
eq "status with no pidfile" "stopped" "$OUT"
eq "status with no pidfile stderr" "" "$ERR"

run stop --pidfile "$P"
eq "stop with no pidfile rc" 3 "$RC"
eq "stop with no pidfile" "not running" "$OUT"

run start --pidfile "$P" --log "$L" -- bash "$W/long.sh"
eq "start rc" 0 "$RC"
eq "start stderr" "" "$ERR"
pid="${OUT#started: }"
eq "start stdout shape" "started: $pid" "$OUT"
case "$pid" in
    ''|*[!0-9]*) echo "FAIL start did not report a numeric pid: [$OUT]" >&2; fails=$((fails + 1)); pid=0 ;;
esac
STARTED+=("$pid")

eq "pidfile holds the pid" "$pid" "$(cat "$P")"
if ! alive "$pid"; then
    echo "FAIL the started process is not running" >&2
    fails=$((fails + 1))
fi

for _ in $(seq 1 60); do
    [ -s "$L" ] && break
    sleep 0.05
done
eq "log captured the command output" "started $pid" "$(cat "$L")"

run status --pidfile "$P"
eq "status running rc" 0 "$RC"
eq "status running" "running: $pid" "$OUT"

run start --pidfile "$P" --log "$L" -- bash "$W/long.sh"
eq "second start rc" 0 "$RC"
eq "second start" "already running: $pid" "$OUT"
eq "pidfile unchanged" "$pid" "$(cat "$P")"

run stop --pidfile "$P" --kill-after 3
eq "stop rc" 0 "$RC"
eq "stop stdout" "stopped: $pid" "$OUT"
if [ -e "$P" ]; then
    echo "FAIL the pidfile survived stop" >&2
    fails=$((fails + 1))
fi
if alive "$pid"; then
    echo "FAIL the process survived stop" >&2
    fails=$((fails + 1))
fi

run status --pidfile "$P"
eq "status after stop rc" 3 "$RC"
eq "status after stop" "stopped" "$OUT"

run stop --pidfile "$P"
eq "second stop rc" 3 "$RC"
eq "second stop" "not running" "$OUT"

exit $((fails > 0 ? 1 : 0))
