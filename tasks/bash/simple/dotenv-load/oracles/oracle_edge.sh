#!/usr/bin/env bash
# hidden - edge cases
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/envcheck.sh"
[ -f "$T" ] || { echo "missing envcheck.sh" >&2; exit 1; }

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

# CRLF endings and a last line with no newline at all
printf 'A=1\r\nB=two\r\n' > "$W/crlf.env"
run --file "$W/crlf.env"
eq "crlf rc" 0 "$RC"
eq "crlf" "$(printf 'A=1\nB=two')" "$OUT"

printf 'A=1\nZ=last' > "$W/nonl.env"
run --file "$W/nonl.env"
eq "no trailing newline" "$(printf 'A=1\nZ=last')" "$OUT"

# quoting corner cases
{
    printf 'MIXED="abc%s\n' "'"
    printf 'EMPTYQ=""\n'
    printf 'ONECHAR="\n'
    printf 'INNER=a"b\n'
    printf 'TABBED=\tvalue\t\n'
    printf 'export\t\tSPACES=ok\n'
    printf '_under=1\n'
    printf 'k9_z=fine\n'
} > "$W/quotes.env"
run --file "$W/quotes.env"
eq "quote corners" "$(printf 'EMPTYQ=\nINNER=a"b\nMIXED="abc%s\nONECHAR="\nSPACES=ok\nTABBED=value\n_under=1\nk9_z=fine' "'")" "$OUT"

# only comments and blanks
printf '# one\n\n   \n# two\n' > "$W/comments.env"
run --file "$W/comments.env"
eq "comments only rc" 0 "$RC"
eq "comments only" "" "$OUT"

# a completely empty file
: > "$W/blank.env"
run --file "$W/blank.env"
eq "empty file rc" 0 "$RC"
eq "empty file" "" "$OUT"

# malformed lines
printf 'GOOD=1\njusttext\n' > "$W/bad1.env"
run --file "$W/bad1.env"
eq "bad line rc" 3 "$RC"
eq "bad line msg" "bad line 2: justtext" "$ERR"

printf 'GOOD=1\n  =oops\n' > "$W/bad2.env"
run --file "$W/bad2.env"
eq "no key rc" 3 "$RC"
eq "no key msg" "$(printf 'bad line 2:   =oops')" "$ERR"

printf '1BAD=x\n' > "$W/bad3.env"
run --file "$W/bad3.env"
eq "key starts with digit rc" 3 "$RC"
eq "key starts with digit msg" "bad line 1: 1BAD=x" "$ERR"

printf 'A=1\nexport\n' > "$W/bad4.env"
run --file "$W/bad4.env"
eq "bare export rc" 3 "$RC"

printf 'HAS-DASH=1\n' > "$W/bad5.env"
run --file "$W/bad5.env"
eq "dash in key rc" 3 "$RC"

# --get on an absent key
printf 'A=1\n' > "$W/small.env"
run --file "$W/small.env" --get NOPE
eq "get absent rc" 4 "$RC"
eq "get absent stderr" "not set: NOPE" "$ERR"
eq "get absent stdout" "" "$OUT"

# a key present but empty is "set" for --get and "missing" for --require
printf 'A=\n' > "$W/emptyval.env"
run --file "$W/emptyval.env" --get A
eq "get empty value rc" 0 "$RC"
run --file "$W/emptyval.env" --require A
eq "require empty value rc" 5 "$RC"
eq "require empty value stderr" "missing: A" "$ERR"

# file and usage errors
run --file "$W/absent.env"
eq "missing file rc" 1 "$RC"
eq "missing file stderr" "no such file: $W/absent.env" "$ERR"

run --get A
eq "no --file rc" 2 "$RC"
run --file "$W/small.env" --get A --require A
eq "get plus require rc" 2 "$RC"
run --file "$W/small.env" --bogus x
eq "unknown option rc" 2 "$RC"
run --file
eq "dangling --file rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
