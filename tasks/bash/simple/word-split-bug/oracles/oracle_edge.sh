#!/usr/bin/env bash
# hidden - edge cases
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

NL=$'\n'
TAB=$'\t'
names=(
    "two${NL}lines.txt"
    "tab${TAB}sep.txt"
    ' leading space.txt'
    'trailing space .txt'
    'bracket[a-z].txt'
    'dollar$var.txt'
)

S="$W/src"
mkdir -p "$S"
for n in "${names[@]}"; do printf 'body of %s' "$n" > "$S/$n"; done

D="$W/dest"
run "$S" "$D"
eq "nasty rc" 0 "$RC"
eq "nasty stdout" "copied: 6" "$OUT"
eq "nasty listing" "$(render "${names[@]}")" "$(listing "$D")"
for n in "${names[@]}"; do
    eq "content preserved" "body of $n" "$(cat "$D/$n")"
done

# an empty source directory
E="$W/emptysrc"
mkdir -p "$E"
ED="$W/emptydest"
run "$E" "$ED"
eq "empty rc" 0 "$RC"
eq "empty stdout" "copied: 0" "$OUT"
if [ ! -d "$ED" ]; then
    echo "FAIL destination was not created for an empty source" >&2
    fails=$((fails + 1))
fi

# a source holding only directories and symlinks
N="$W/nofiles"
mkdir -p "$N/inner"
ln -s /nowhere "$N/dangling"
run "$N" "$W/nofilesdest"
eq "no regular files stdout" "copied: 0" "$OUT"

# a destination that already exists keeps unrelated files
K="$W/keepdest"
mkdir -p "$K"
printf 'mine\n' > "$K/unrelated.txt"
run "$S" "$K"
eq "existing dest rc" 0 "$RC"
eq "existing dest kept file" "mine" "$(cat "$K/unrelated.txt")"
want=("${names[@]}" 'unrelated.txt')
eq "existing dest listing" "$(render "${want[@]}")" "$(listing "$K")"

# a source directory whose own name has a space
SP="$W/src with space"
mkdir -p "$SP"
printf 'z' > "$SP/a b.txt"
run "$SP" "$W/dest with space"
eq "spaced dirs rc" 0 "$RC"
eq "spaced dirs stdout" "copied: 1" "$OUT"
eq "spaced dirs content" "z" "$(cat "$W/dest with space/a b.txt")"

# missing source
run "$W/absent" "$W/d2"
eq "missing src rc" 1 "$RC"
eq "missing src stderr" "no such directory: $W/absent" "$ERR"

printf 'x' > "$W/afile"
run "$W/afile" "$W/d3"
eq "file as src rc" 1 "$RC"

# argument count
run
eq "no args rc" 2 "$RC"
run "$S"
eq "one arg rc" 2 "$RC"
run "$S" "$W/d4" extra
eq "three args rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
