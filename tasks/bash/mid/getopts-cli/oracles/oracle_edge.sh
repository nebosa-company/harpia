#!/usr/bin/env bash
# hidden - edge cases
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/tool.sh"
[ -f "$T" ] || { echo "missing tool.sh" >&2; exit 1; }

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

D="$W/store"
mkdir -p "$D"

# -h prints usage on stdout and stops
run -h
eq "-h rc" 0 "$RC"
eq "-h stderr" "" "$ERR"
if [ -z "$OUT" ]; then
    echo "FAIL -h printed nothing on stdout" >&2
    fails=$((fails + 1))
fi
run -h list
eq "-h before subcommand rc" 0 "$RC"

# bundled short options: -vC DIR is -v -C DIR
run -vC "$D" list
eq "bundled rc" 0 "$RC"
eq "bundled verbose line" "store: $D/records.tsv" "$ERR"
eq "bundled empty store" "" "$OUT"

# -v on its own uses the default store directory
run -v list
eq "default dir verbose" "store: ./records.tsv" "$ERR"

# a bare -- ends global option parsing
run -C "$D" -- add -n keep -V 'via dashdash'
eq "dashdash rc" 0 "$RC"
eq "dashdash stdout" "added: keep" "$OUT"

# listing a store that has never been written
run -C "$W/never" list
eq "absent store rc" 0 "$RC"
eq "absent store stdout" "" "$OUT"
run -C "$W/never" get -n x
eq "get from absent store rc" 5 "$RC"
run -C "$W/never" remove -n x
eq "remove from absent store rc" 5 "$RC"

# values may hold spaces, quotes and option-looking text
run -C "$D" add -n odd -V '  -n not an option  ' -t 'two words'
eq "odd value rc" 0 "$RC"
run -C "$D" get -n odd
eq "odd value" "  -n not an option  " "$OUT"
run -C "$D" list -t 'two words'
eq "tag with space" "$(printf 'odd\t  -n not an option  \ttwo words')" "$OUT"

# an empty value is allowed
run -C "$D" add -n blank -V ''
eq "empty value rc" 0 "$RC"
run -C "$D" get -n blank
eq "empty value read back" "" "$OUT"

# removing one record leaves the rest untouched
before="$(bash "$T" -C "$D" list)"
run -C "$D" add -n doomed -V 'temporary'
run -C "$D" remove -n doomed
eq "restore rc" 0 "$RC"
run -C "$D" list
eq "store restored" "$before" "$OUT"

# usage errors
run
eq "no subcommand rc" 2 "$RC"
run -C "$D"
eq "options but no subcommand rc" 2 "$RC"
run -C "$D" frobnicate
eq "unknown subcommand rc" 2 "$RC"
run -Z -C "$D" list
eq "unknown global option rc" 2 "$RC"
run -C
eq "missing -C argument rc" 2 "$RC"
run -C "$D" add -n only
eq "add without -V rc" 2 "$RC"
run -C "$D" add -V only
eq "add without -n rc" 2 "$RC"
run -C "$D" add -n x -V y -q z
eq "unknown subcommand option rc" 2 "$RC"
run -C "$D" add -n x -V
eq "missing -V argument rc" 2 "$RC"
run -C "$D" get
eq "get without -n rc" 2 "$RC"
run -C "$D" remove
eq "remove without -n rc" 2 "$RC"
run -C "$D" list extra
eq "positional after list rc" 2 "$RC"
run -C "$D" add -n 'bad name' -V v
eq "name with a space rc" 2 "$RC"
run -C "$D" add -n 'bang!' -V v
eq "name with punctuation rc" 2 "$RC"
run -C "$D" add -n '' -V v
eq "empty name rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
