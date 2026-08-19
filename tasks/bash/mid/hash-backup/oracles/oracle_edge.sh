#!/usr/bin/env bash
# hidden - edge cases
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/snapshot.sh"
[ -f "$T" ] || { echo "missing snapshot.sh" >&2; exit 1; }

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
sha() { sha256sum -- "$1" | cut -d' ' -f1; }
manifest_of() {
    find "$1" -type f -print0 | sort -z | while IFS= read -r -d '' f; do
        printf '%s\t%s\n' "$(sha "$f")" "${f#"$1"/}"
    done
}

EMPTY_SHA=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855

# an empty file is an ordinary file
S="$W/src"
D="$W/store"
mkdir -p "$S/sub"
: > "$S/nothing.dat"
: > "$S/sub/also-nothing.dat"
printf 'x' > "$S/x.dat"
run --source "$S" --store "$D"
eq "empty files rc" 0 "$RC"
eq "empty files stdout" "new: 2 reused: 1" "$OUT"
eq "empty object stored" "yes" "$([ -f "$D/objects/${EMPTY_SHA:0:2}/${EMPTY_SHA:2}" ] && echo yes)"
eq "empty files manifest" "$(manifest_of "$S")" "$(cat "$D/manifest.tsv")"

# a trailing slash on the source does not change the relative paths
run --source "$S/" --store "$D"
eq "trailing slash rc" 0 "$RC"
eq "trailing slash manifest" "$(manifest_of "$S")" "$(cat "$D/manifest.tsv")"

# an entirely empty source
E="$W/emptysrc"
ED="$W/emptystore"
mkdir -p "$E"
run --source "$E" --store "$ED"
eq "empty source rc" 0 "$RC"
eq "empty source stdout" "new: 0 reused: 0" "$OUT"
eq "empty source manifest exists" "yes" "$([ -f "$ED/manifest.tsv" ] && echo yes)"
eq "empty source manifest" "" "$(cat "$ED/manifest.tsv")"
run --verify "$ED"
eq "verify empty store" "ok: 0" "$OUT"

# a store that was never written has nothing to verify
run --verify "$W/never-a-store"
eq "verify absent store rc" 0 "$RC"
eq "verify absent store" "ok: 0" "$OUT"

# a second source shares objects with the first
S2="$W/src2"
mkdir -p "$S2"
printf 'x' > "$S2/copy-of-x.dat"
printf 'brand new\n' > "$S2/other.dat"
D2="$W/store2"
run --source "$S" --store "$D2"
eq "seed store2 rc" 0 "$RC"
run --source "$S2" --store "$D2"
eq "shared objects stdout" "new: 1 reused: 1" "$OUT"

# corruption is detected and named
CS="$W/corrupt"
run --source "$S" --store "$CS"
eq "corrupt seed rc" 0 "$RC"
xsha="$(sha "$S/x.dat")"
printf 'tampered' > "$CS/objects/${xsha:0:2}/${xsha:2}"
run --verify "$CS"
eq "corrupt rc" 5 "$RC"
eq "corrupt stderr" "corrupt: $xsha" "$ERR"
eq "corrupt stdout" "" "$OUT"

# two corrupt objects are reported in ascending order
printf 'also tampered' > "$CS/objects/${EMPTY_SHA:0:2}/${EMPTY_SHA:2}"
run --verify "$CS"
eq "two corrupt rc" 5 "$RC"
eq "two corrupt stderr" "$(printf 'corrupt: %s\ncorrupt: %s\n' "$xsha" "$EMPTY_SHA" | sort)" "$ERR"

# missing source
run --source "$W/absent" --store "$D"
eq "missing source rc" 1 "$RC"
eq "missing source stderr" "no such directory: $W/absent" "$ERR"

# usage errors
run
eq "no options rc" 2 "$RC"
run --source "$S"
eq "source only rc" 2 "$RC"
run --store "$D"
eq "store only rc" 2 "$RC"
run --verify "$D" --source "$S"
eq "both modes rc" 2 "$RC"
run --source "$S" --store "$D" --bogus
eq "unknown option rc" 2 "$RC"
run --verify
eq "dangling --verify rc" 2 "$RC"
run --source
eq "dangling --source rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
