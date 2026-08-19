#!/usr/bin/env bash
# hidden - edge cases
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/rename.sh"
[ -f "$T" ] || { echo "missing rename.sh" >&2; exit 1; }

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

# names containing newline and tab characters survive intact
D="$W/nasty"
mkdir -p "$D"
nasty=( "line one${NL}line two.txt" "tab${TAB}sep.txt" "  leading spaces.txt" "trailing space .txt" )
for n in "${nasty[@]}"; do printf 'x' > "$D/$n"; done

run --prefix v1_ "$D"
eq "nasty rc" 0 "$RC"
eq "nasty stdout" "renamed: 4" "$OUT"
want=()
for n in "${nasty[@]}"; do want+=("v1_$n"); done
eq "nasty listing" "$(render "${want[@]}")" "$(listing "$D")"
eq "newline name content" "x" "$(cat "$D/v1_line one${NL}line two.txt")"

# a collision aborts the whole batch
D2="$W/clash"
mkdir -p "$D2"
printf 'a' > "$D2/alpha.txt"
printf 'b' > "$D2/beta.txt"
printf 'old' > "$D2/v1_beta.txt"
before="$(listing "$D2")"
run --prefix v1_ "$D2"
eq "collision rc" 3 "$RC"
eq "collision stderr" "exists: v1_beta.txt" "$ERR"
eq "collision renamed nothing" "$before" "$(listing "$D2")"
eq "collision left target alone" "old" "$(cat "$D2/v1_beta.txt")"

# dry run reports the same collision and still exits 3
run --dry-run --prefix v1_ "$D2"
eq "dry collision rc" 3 "$RC"
eq "dry collision stderr" "exists: v1_beta.txt" "$ERR"

# two collisions are both reported, sorted
D3="$W/clash2"
mkdir -p "$D3"
for n in zulu.txt alpha.txt; do printf 'x' > "$D3/$n"; printf 'y' > "$D3/v1_$n"; done
run --prefix v1_ "$D3"
eq "two collisions rc" 3 "$RC"
eq "two collisions stderr" "$(printf 'exists: v1_alpha.txt\nexists: v1_zulu.txt')" "$ERR"

# empty directory
D4="$W/empty"
mkdir -p "$D4"
run --prefix v1_ "$D4"
eq "empty rc" 0 "$RC"
eq "empty stdout" "renamed: 0" "$OUT"

# directory holding only subdirectories and symlinks
D5="$W/nofiles"
mkdir -p "$D5/inner"
ln -s /nowhere "$D5/dangling"
run --prefix v1_ "$D5"
eq "no regular files rc" 0 "$RC"
eq "no regular files stdout" "renamed: 0" "$OUT"
eq "no regular files listing" "$(render 'inner' 'dangling')" "$(listing "$D5")"

# missing directory
run --prefix v1_ "$W/absent"
eq "missing dir rc" 1 "$RC"
eq "missing dir stderr" "not a directory: $W/absent" "$ERR"

# a plain file where a directory is expected
printf 'x' > "$W/afile"
run --prefix v1_ "$W/afile"
eq "file not dir rc" 1 "$RC"

# usage errors
run "$W/empty"
eq "no prefix rc" 2 "$RC"
run --prefix '' "$W/empty"
eq "empty prefix rc" 2 "$RC"
run --prefix v1_
eq "no dir rc" 2 "$RC"
run --bogus --prefix v1_ "$W/empty"
eq "unknown option rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
