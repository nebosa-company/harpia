#!/usr/bin/env bash
# hidden - core behaviour
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

D="$W/vol"
mkf "$D/alpha/f1.bin" 1536
mkf "$D/beta/x/y/f2.bin" 2097152
mkf "$D/gamma/f3.bin" 512
mkdir -p "$D/delta"
mkf "$D/epsilon/sub/f4.bin" 1024
mkf "$D/epsilon/f5.bin" 512
mkf "$D/loose.bin" 999999
ln -s alpha "$D/linkdir"
ln -s ../loose.bin "$D/gamma/link.bin"

want="$(printf '2.0M\tbeta\n1.5K\talpha\n1.5K\tepsilon\n512B\tgamma\n0B\tdelta\n2.0M\tTOTAL')"
run "$D"
eq "report rc" 0 "$RC"
eq "report" "$want" "$OUT"
eq "report stderr" "" "$ERR"

run --top 2 "$D"
eq "top 2" "$(printf '2.0M\tbeta\n1.5K\talpha\n2.0M\tTOTAL')" "$OUT"

run --top 1 "$D"
eq "top 1" "$(printf '2.0M\tbeta\n2.0M\tTOTAL')" "$OUT"

run --top 10 "$D"
eq "top beyond the end" "$want" "$OUT"

# option after the directory works too
run "$D" --top 2
eq "option after dir" "$(printf '2.0M\tbeta\n1.5K\talpha\n2.0M\tTOTAL')" "$OUT"

exit $((fails > 0 ? 1 : 0))
