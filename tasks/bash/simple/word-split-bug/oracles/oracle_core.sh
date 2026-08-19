#!/usr/bin/env bash
# hidden - core behaviour
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/backup.sh"
[ -f "$T" ] || { echo "missing backup.sh" >&2; exit 1; }

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
listing() {
    find "$1" -mindepth 1 -maxdepth 1 -printf '%f\0' | sort -z |
        while IFS= read -r -d '' n; do printf '%q\n' "$n"; done
}
render() {
    printf '%s\0' "$@" | sort -z |
        while IFS= read -r -d '' n; do printf '%q\n' "$n"; done
}

names=(
    'plain.txt'
    'two words.txt'
    '-dash.txt'
    'star*.txt'
    'quest?.txt'
    "quote'.txt"
)

S="$W/src"
mkdir -p "$S/sub"
for n in "${names[@]}"; do printf 'body of %s\n' "$n" > "$S/$n"; done
printf 'inner\n' > "$S/sub/inner.txt"
ln -s 'plain.txt' "$S/link.txt"
srcbefore="$(listing "$S")"

D="$W/dest"
run "$S" "$D"
eq "copy rc" 0 "$RC"
eq "copy stdout" "copied: 6" "$OUT"
eq "copy stderr" "" "$ERR"
eq "dest listing" "$(render "${names[@]}")" "$(listing "$D")"
eq "source untouched" "$srcbefore" "$(listing "$S")"

for n in "${names[@]}"; do
    eq "content of $n" "body of $n" "$(cat "$D/$n")"
done

if [ -e "$D/sub" ]; then
    echo "FAIL subdirectory was copied" >&2
    fails=$((fails + 1))
fi
if [ -e "$D/link.txt" ]; then
    echo "FAIL symlink was copied" >&2
    fails=$((fails + 1))
fi

# copying again over an existing destination overwrites cleanly
printf 'stale\n' > "$D/plain.txt"
run "$S" "$D"
eq "second copy stdout" "copied: 6" "$OUT"
eq "overwrote stale file" "body of plain.txt" "$(cat "$D/plain.txt")"
eq "dest listing after second copy" "$(render "${names[@]}")" "$(listing "$D")"

exit $((fails > 0 ? 1 : 0))
