#!/usr/bin/env bash
# hidden - edge cases
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/dirsize.sh"
[ -f "$T" ] || { echo "missing dirsize.sh" >&2; exit 1; }

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
mkf() {
    mkdir -p "$(dirname -- "$1")"
    truncate -s "$2" "$1"
}

# every unit boundary
U="$W/units"
mkf "$U/gig/f" 1073741824
mkf "$U/meg/f" 1048576
mkf "$U/kay/f" 1024
mkf "$U/just-under/f" 1023
mkdir -p "$U/nothing"
run "$U"
eq "units rc" 0 "$RC"
eq "units" "$(printf '1.0G\tgig\n1.0M\tmeg\n1.0K\tkay\n1023B\tjust-under\n0B\tnothing\n1.0G\tTOTAL')" "$OUT"

# equal totals sort by name, hidden and spaced names included
N="$W/names"
mkf "$N/bb/f" 100
mkf "$N/aa/f" 100
mkf "$N/.hidden/f" 100
mkf "$N/two words/f" 100
run "$N"
eq "name ordering" "$(printf '100B\t.hidden\n100B\taa\n100B\tbb\n100B\ttwo words\n400B\tTOTAL')" "$OUT"

# --top does not change TOTAL
run --top 2 "$N"
eq "top keeps total" "$(printf '100B\t.hidden\n100B\taa\n400B\tTOTAL')" "$OUT"

# a directory with no subdirectories at all
F="$W/flat"
mkf "$F/only.bin" 4096
run "$F"
eq "no subdirs rc" 0 "$RC"
eq "no subdirs" "$(printf '0B\tTOTAL')" "$OUT"

# an entirely empty directory
mkdir -p "$W/void"
run "$W/void"
eq "void" "$(printf '0B\tTOTAL')" "$OUT"

# missing and non-directory arguments
run "$W/absent"
eq "missing dir rc" 1 "$RC"
eq "missing dir stderr" "not a directory: $W/absent" "$ERR"
mkf "$W/plain" 10
run "$W/plain"
eq "file as dir rc" 1 "$RC"

# usage errors
run
eq "no args rc" 2 "$RC"
run --top 0 "$N"
eq "zero top rc" 2 "$RC"
run --top -1 "$N"
eq "negative top rc" 2 "$RC"
run --top abc "$N"
eq "non-numeric top rc" 2 "$RC"
run --top
eq "dangling --top rc" 2 "$RC"
run --bogus "$N"
eq "unknown option rc" 2 "$RC"
run "$N" "$U"
eq "two directories rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
