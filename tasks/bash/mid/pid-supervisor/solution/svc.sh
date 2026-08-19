#!/usr/bin/env bash
# Pidfile supervisor: start, stop, status, restart.
set -u
export LC_ALL=C

usage() {
    echo "usage: svc.sh start|stop|status|restart --pidfile P [--log L] [--kill-after S] [-- CMD ...]" >&2
}

[ $# -ge 1 ] || { usage; exit 2; }
ACTION="$1"
shift
case "$ACTION" in
    start|stop|status|restart) ;;
    *) usage; exit 2 ;;
esac

PIDFILE=""
LOG=""
KILLAFTER=5
SAW_SEP=0
CMD=()

while [ $# -gt 0 ]; do
    case "$1" in
        --pidfile)    [ $# -ge 2 ] || { usage; exit 2; }; PIDFILE="$2"; shift 2 ;;
        --log)        [ $# -ge 2 ] || { usage; exit 2; }; LOG="$2"; shift 2 ;;
        --kill-after) [ $# -ge 2 ] || { usage; exit 2; }; KILLAFTER="$2"; shift 2 ;;
        --)           SAW_SEP=1; shift; CMD=("$@"); break ;;
        *)            usage; exit 2 ;;
    esac
done

[ -n "$PIDFILE" ] || { usage; exit 2; }
case "$KILLAFTER" in
    ''|*[!0-9]*) usage; exit 2 ;;
esac
[ -n "$LOG" ] || LOG="$PIDFILE.log"

case "$ACTION" in
    start|restart)
        [ "$SAW_SEP" -eq 1 ] || { usage; exit 2; }
        [ ${#CMD[@]} -ge 1 ] || { usage; exit 2; }
        ;;
    stop|status)
        [ "$SAW_SEP" -eq 0 ] || { usage; exit 2; }
        ;;
esac

STATE=""
PID=""
compute_state() {
    PID=""
    if [ ! -f "$PIDFILE" ]; then
        STATE=missing
        return
    fi
    local p
    p="$(head -n 1 -- "$PIDFILE" 2>/dev/null)"
    p="${p//[$'\r'$'\n' ]/}"
    case "$p" in
        ''|*[!0-9]*) STATE=stale; return ;;
    esac
    PID="$p"
    if kill -0 "$PID" 2>/dev/null; then
        STATE=running
    else
        STATE=stale
    fi
}

wait_gone() { # pid, tenths of a second
    local p="$1" limit="$2" n=0
    while kill -0 "$p" 2>/dev/null; do
        [ "$n" -ge "$limit" ] && return 1
        sleep 0.1
        n=$((n + 1))
    done
    return 0
}

do_start() {
    compute_state
    if [ "$STATE" = running ]; then
        printf 'already running: %s\n' "$PID"
        return 0
    fi
    "${CMD[@]}" < /dev/null >> "$LOG" 2>&1 &
    local pid=$!
    printf '%s\n' "$pid" > "$PIDFILE"
    printf 'started: %s\n' "$pid"
    return 0
}

terminate() { # only called when STATE is running
    kill -TERM "$PID" 2>/dev/null
    if wait_gone "$PID" $((KILLAFTER * 10)); then
        rm -f -- "$PIDFILE"
        printf 'stopped: %s\n' "$PID"
    else
        kill -KILL "$PID" 2>/dev/null
        wait_gone "$PID" 100
        rm -f -- "$PIDFILE"
        printf 'killed: %s\n' "$PID"
    fi
}

case "$ACTION" in
    status)
        compute_state
        case "$STATE" in
            missing) printf 'stopped\n'; exit 3 ;;
            stale)   printf 'stale\n'; exit 4 ;;
            running) printf 'running: %s\n' "$PID"; exit 0 ;;
        esac
        ;;
    stop)
        compute_state
        case "$STATE" in
            missing) printf 'not running\n'; exit 3 ;;
            stale)   rm -f -- "$PIDFILE"; printf 'stale\n'; exit 0 ;;
            running) terminate; exit 0 ;;
        esac
        ;;
    start)
        do_start
        exit 0
        ;;
    restart)
        compute_state
        case "$STATE" in
            running) terminate ;;
            stale)   rm -f -- "$PIDFILE" ;;
            missing) ;;
        esac
        do_start
        exit 0
        ;;
esac
