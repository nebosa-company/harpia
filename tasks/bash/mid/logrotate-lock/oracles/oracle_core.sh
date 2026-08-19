#!/usr/bin/env bash
# hidden - core behaviour
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/rotate.sh"
[ -f "$T" ] || { echo "missing rotate.sh" >&2; exit 1; }

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
sibs() {
    find "$(dirname -- "$1")" -mindepth 1 -maxdepth 1 -name "$(basename -- "$1").*" -printf '%f\n' |
        grep -v '\.lock$' | sort
}

D="$W/logs"
mkdir -p "$D"
L="$D/app.log"

write_log() { printf '%s\n' "$1" > "$L"; }

write_log v0
run --file "$L" --keep 3 --max-bytes 1
eq "first rotation rc" 0 "$RC"
eq "first rotation stdout" "rotated: $L" "$OUT"
eq "first rotation stderr" "" "$ERR"
eq "log emptied" "" "$(cat "$L")"
eq "log still exists" "yes" "$([ -f "$L" ] && echo yes)"
eq "generation 1" "v0" "$(cat "$L.1")"
eq "siblings after one" "app.log.1" "$(sibs "$L")"

write_log v1
run --file "$L" --keep 3 --max-bytes 1
eq "second rotation rc" 0 "$RC"
eq "gen 1 after two" "v1" "$(cat "$L.1")"
eq "gen 2 after two" "v0" "$(cat "$L.2")"
eq "siblings after two" "$(printf 'app.log.1\napp.log.2')" "$(sibs "$L")"

write_log v2
run --file "$L" --keep 3 --max-bytes 1
eq "gen 1 after three" "v2" "$(cat "$L.1")"
eq "gen 2 after three" "v1" "$(cat "$L.2")"
eq "gen 3 after three" "v0" "$(cat "$L.3")"

write_log v3
run --file "$L" --keep 3 --max-bytes 1
eq "fourth rotation rc" 0 "$RC"
eq "gen 1 after four" "v3" "$(cat "$L.1")"
eq "gen 2 after four" "v2" "$(cat "$L.2")"
eq "gen 3 after four" "v1" "$(cat "$L.3")"
eq "oldest dropped" "$(printf 'app.log.1\napp.log.2\napp.log.3')" "$(sibs "$L")"

# below the threshold nothing happens at all
S="$W/small"
mkdir -p "$S"
SL="$S/tiny.log"
printf 'only a few bytes\n' > "$SL"
run --file "$SL" --keep 2 --max-bytes 1048576
eq "below threshold rc" 0 "$RC"
eq "below threshold stdout" "" "$OUT"
eq "below threshold stderr" "" "$ERR"
eq "below threshold content" "only a few bytes" "$(cat "$SL")"
eq "below threshold siblings" "" "$(sibs "$SL")"

# a second caller is refused while the lock is held
B="$W/busy"
mkdir -p "$B"
BL="$B/held.log"
printf 'plenty of content here\n' > "$BL"
( flock -x 9; sleep 3 ) 9> "$BL.lock" &
holder=$!
sleep 0.4
run --file "$BL" --keep 2 --max-bytes 1 --wait 1
eq "busy rc" 4 "$RC"
eq "busy stderr" "busy: $BL" "$ERR"
eq "busy stdout" "" "$OUT"
eq "busy left the log alone" "plenty of content here" "$(cat "$BL")"
eq "busy rotated nothing" "" "$(sibs "$BL")"
wait "$holder"

# once the lock is free the same call succeeds
run --file "$BL" --keep 2 --max-bytes 1 --wait 1
eq "after lock rc" 0 "$RC"
eq "after lock stdout" "rotated: $BL" "$OUT"
eq "after lock gen 1" "plenty of content here" "$(cat "$BL.1")"

exit $((fails > 0 ? 1 : 0))
