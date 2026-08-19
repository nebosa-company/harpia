#!/usr/bin/env bash
# hidden - core behaviour
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

{
    printf '# a comment\n'
    printf '   # an indented comment\n'
    printf '\n'
    printf '   \t \n'
    printf 'APP_NAME=demo\n'
    printf 'export DB_URL=postgres://localhost/app\n'
    printf '  SPACED  =   value with spaces   \n'
    printf 'QUOTED="  keep  inner  "\n'
    printf "SQUOTED='  single  '\n"
    printf 'EMPTY=\n'
    printf 'EQUALS=a=b=c\n'
    printf 'LITERAL=$HOME/$(date)/`whoami`\n'
    printf 'APP_NAME=override\n'
} > "$W/app.env"

want="$(printf 'APP_NAME=override\nDB_URL=postgres://localhost/app\nEMPTY=\nEQUALS=a=b=c\nLITERAL=$HOME/$(date)/`whoami`\nQUOTED=  keep  inner  \nSPACED=value with spaces\nSQUOTED=  single  \n')"
run --file "$W/app.env"
eq "dump rc" 0 "$RC"
eq "dump" "$want" "$OUT"
eq "dump stderr" "" "$ERR"

run --file "$W/app.env" --get APP_NAME
eq "get override rc" 0 "$RC"
eq "get override" "override" "$OUT"

run --file "$W/app.env" --get DB_URL
eq "get exported" "postgres://localhost/app" "$OUT"

run --file "$W/app.env" --get SPACED
eq "get trimmed" "value with spaces" "$OUT"

run --file "$W/app.env" --get QUOTED
eq "get double quoted" "  keep  inner  " "$OUT"

run --file "$W/app.env" --get SQUOTED
eq "get single quoted" "  single  " "$OUT"

run --file "$W/app.env" --get EQUALS
eq "get value with equals" "a=b=c" "$OUT"

run --file "$W/app.env" --get LITERAL
eq "get literal" '$HOME/$(date)/`whoami`' "$OUT"

run --file "$W/app.env" --get EMPTY
eq "get empty rc" 0 "$RC"
eq "get empty" "" "$OUT"

run --file "$W/app.env" --require APP_NAME,DB_URL,SPACED
eq "require satisfied rc" 0 "$RC"
eq "require satisfied stdout" "" "$OUT"
eq "require satisfied stderr" "" "$ERR"

run --file "$W/app.env" --require NOPE,EMPTY,APP_NAME
eq "require unsatisfied rc" 5 "$RC"
eq "require unsatisfied stderr" "$(printf 'missing: EMPTY\nmissing: NOPE')" "$ERR"

exit $((fails > 0 ? 1 : 0))
