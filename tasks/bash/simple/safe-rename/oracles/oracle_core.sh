#!/usr/bin/env bash
# hidden - core behaviour
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
# Render a directory's depth-1 entries, one shell-quoted name per line.
listing() {
    find "$1" -mindepth 1 -maxdepth 1 -printf '%f\0' | sort -z |
        while IFS= read -r -d '' n; do printf '%q\n' "$n"; done
}
# Render an explicit list of names the same way, for comparison.
render() {
    printf '%s\0' "$@" | sort -z |
        while IFS= read -r -d '' n; do printf '%q\n' "$n"; done
}

names=(
    'plain.txt'
    'two words.txt'
    '-leading-dash.txt'
    'star*glob.txt'
    "quote'single.txt"
    'double"quote.txt'
    'back\slash.txt'
)

build() {
    rm -rf "$1"
    mkdir -p "$1/sub"
    local n
    for n in "${names[@]}"; do printf 'body of %s\n' "$n" > "$1/$n"; done
    printf 'inner\n' > "$1/sub/inner.txt"
    ln -s 'plain.txt' "$1/link.txt"
}

D="$W/arch"
build "$D"

run --prefix arc_ "$D"
eq "rename rc" 0 "$RC"
eq "rename stdout" "renamed: 7" "$OUT"
eq "rename stderr" "" "$ERR"

after=()
for n in "${names[@]}"; do after+=("arc_$n"); done
after+=('sub' 'link.txt')
eq "listing after rename" "$(render "${after[@]}")" "$(listing "$D")"

eq "content preserved" "body of two words.txt" "$(cat "$D/arc_two words.txt")"
eq "leading dash preserved" "body of -leading-dash.txt" "$(cat "$D/arc_-leading-dash.txt")"
eq "glob name preserved" "body of star*glob.txt" "$(cat "$D/arc_star*glob.txt")"
eq "subdir untouched" "inner" "$(cat "$D/sub/inner.txt")"

# a second pass is a no-op: everything already carries the prefix
run --prefix arc_ "$D"
eq "second pass rc" 0 "$RC"
eq "second pass stdout" "renamed: 0" "$OUT"
eq "second pass listing" "$(render "${after[@]}")" "$(listing "$D")"

# dry run reports the plan and changes nothing
D2="$W/dry"
build "$D2"
before="$(listing "$D2")"
want="$(
    printf '%s\0' "${names[@]}" | sort -z |
        while IFS= read -r -d '' n; do printf '%s -> arc_%s\n' "$n" "$n"; done
    printf 'renamed: 7\n'
)"
run --dry-run --prefix arc_ "$D2"
eq "dry-run rc" 0 "$RC"
eq "dry-run stdout" "$want" "$OUT"
eq "dry-run changed nothing" "$before" "$(listing "$D2")"

exit $((fails > 0 ? 1 : 0))
