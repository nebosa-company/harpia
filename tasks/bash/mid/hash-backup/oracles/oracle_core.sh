#!/usr/bin/env bash
# hidden - core behaviour
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
objects_of() {
    find "$1/objects" -type f -printf '%P\n' 2>/dev/null | sort
}

S="$W/src"
D="$W/store"
mkdir -p "$S/dir/deep" "$S/emptydir"
printf 'hello\n' > "$S/a.txt"
printf 'hello\n' > "$S/dir/b.txt"
printf 'world\n' > "$S/dir/deep/c.txt"
printf 'spaced\n' > "$S/two words.txt"
ln -s a.txt "$S/link.txt"

run --source "$S" --store "$D"
eq "first run rc" 0 "$RC"
eq "first run stdout" "new: 3 reused: 1" "$OUT"
eq "first run stderr" "" "$ERR"
eq "first manifest" "$(manifest_of "$S")" "$(cat "$D/manifest.tsv")"

h_hello="$(sha "$S/a.txt")"
h_world="$(sha "$S/dir/deep/c.txt")"
h_spaced="$(sha "$S/two words.txt")"
want_objs="$(printf '%s/%s\n%s/%s\n%s/%s\n' \
    "${h_hello:0:2}" "${h_hello:2}" \
    "${h_world:0:2}" "${h_world:2}" \
    "${h_spaced:0:2}" "${h_spaced:2}" | sort)"
eq "object layout" "$want_objs" "$(objects_of "$D")"
eq "object content" "hello" "$(cat "$D/objects/${h_hello:0:2}/${h_hello:2}")"

# an unchanged tree stores nothing new
run --source "$S" --store "$D"
eq "second run rc" 0 "$RC"
eq "second run stdout" "new: 0 reused: 4" "$OUT"
eq "second manifest" "$(manifest_of "$S")" "$(cat "$D/manifest.tsv")"
eq "objects unchanged" "$want_objs" "$(objects_of "$D")"

# one new file adds exactly one object
printf 'fresh\n' > "$S/dir/d.txt"
run --source "$S" --store "$D"
eq "third run stdout" "new: 1 reused: 4" "$OUT"
eq "third manifest" "$(manifest_of "$S")" "$(cat "$D/manifest.tsv")"

run --verify "$D"
eq "verify rc" 0 "$RC"
eq "verify stdout" "ok: 4" "$OUT"
eq "verify stderr" "" "$ERR"

# a removed source file leaves the manifest, but its object stays
rm -- "$S/dir/d.txt"
run --source "$S" --store "$D"
eq "after removal stdout" "new: 0 reused: 4" "$OUT"
eq "after removal manifest" "$(manifest_of "$S")" "$(cat "$D/manifest.tsv")"
run --verify "$D"
eq "verify after removal" "ok: 4" "$OUT"

exit $((fails > 0 ? 1 : 0))
