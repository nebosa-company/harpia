#!/usr/bin/env bash
# hidden - edge cases
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

# --keep 1 keeps exactly one generation
K="$W/keep1"
mkdir -p "$K"
KL="$K/one.log"
printf 'first\n' > "$KL"
run --file "$KL" --keep 1 --max-bytes 1
printf 'second\n' > "$KL"
run --file "$KL" --keep 1 --max-bytes 1
eq "keep 1 rc" 0 "$RC"
eq "keep 1 generation" "second" "$(cat "$KL.1")"
eq "keep 1 siblings" "one.log.1" "$(sibs "$KL")"

# generations left over from a larger --keep are cleaned up
O="$W/overflow"
mkdir -p "$O"
OL="$O/app.log"
printf 'current\n' > "$OL"
for i in 1 2 3 4 5; do printf 'old %s\n' "$i" > "$OL.$i"; done
printf 'not a generation\n' > "$OL.bak"
run --file "$OL" --keep 2 --max-bytes 1
eq "overflow rc" 0 "$RC"
eq "overflow siblings" "$(printf 'app.log.1\napp.log.2\napp.log.bak')" "$(sibs "$OL")"
eq "overflow gen 1" "current" "$(cat "$OL.1")"
eq "overflow gen 2" "old 1" "$(cat "$OL.2")"
eq "non-numeric suffix untouched" "not a generation" "$(cat "$OL.bak")"

# the size test is inclusive at the threshold
E="$W/exact"
mkdir -p "$E"
EL="$E/exact.log"
truncate -s 100 "$EL"
run --file "$EL" --keep 2 --max-bytes 100
eq "size equal to threshold rotates" "rotated: $EL" "$OUT"

truncate -s 99 "$EL"
run --file "$EL" --keep 2 --max-bytes 100
eq "size just below threshold rc" 0 "$RC"
eq "size just below threshold" "" "$OUT"

# a zero threshold always rotates, even an empty log
Z="$W/zero"
mkdir -p "$Z"
ZL="$Z/empty.log"
: > "$ZL"
run --file "$ZL" --keep 2 --max-bytes 0
eq "zero threshold" "rotated: $ZL" "$OUT"
eq "zero threshold gen 1 empty" "" "$(cat "$ZL.1")"

# the default threshold leaves a small log alone
DFT="$W/default"
mkdir -p "$DFT"
DL="$DFT/d.log"
truncate -s 1000 "$DL"
run --file "$DL" --keep 2
eq "default threshold rc" 0 "$RC"
eq "default threshold" "" "$OUT"
truncate -s 1048576 "$DL"
run --file "$DL" --keep 2
eq "default threshold reached" "rotated: $DL" "$OUT"

# a path containing a space
SP="$W/dir with space"
mkdir -p "$SP"
SL="$SP/my log.log"
printf 'spaced\n' > "$SL"
run --file "$SL" --keep 2 --max-bytes 1
eq "spaced path rc" 0 "$RC"
eq "spaced path stdout" "rotated: $SL" "$OUT"
eq "spaced path gen 1" "spaced" "$(cat "$SL.1")"

# missing log
run --file "$W/nope.log" --keep 2
eq "missing log rc" 1 "$RC"
eq "missing log stderr" "no such file: $W/nope.log" "$ERR"

# usage errors
run --keep 2
eq "no --file rc" 2 "$RC"
run --file "$KL"
eq "no --keep rc" 2 "$RC"
run --file "$KL" --keep 0
eq "zero keep rc" 2 "$RC"
run --file "$KL" --keep abc
eq "non-numeric keep rc" 2 "$RC"
run --file "$KL" --keep 2 --max-bytes -1
eq "negative max-bytes rc" 2 "$RC"
run --file "$KL" --keep 2 --wait x
eq "non-numeric wait rc" 2 "$RC"
run --file "$KL" --keep 2 --bogus
eq "unknown option rc" 2 "$RC"
run --file
eq "dangling --file rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
