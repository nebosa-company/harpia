#!/usr/bin/env bash
# hidden - core behaviour
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/render.sh"
[ -f "$T" ] || { echo "missing render.sh" >&2; exit 1; }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
fails=0
eq() {
    if [ "$2" = "$3" ]; then return 0; fi
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$2" "$3" >&2
    fails=$((fails + 1))
}
# Build an expected string, trailing newlines included.
lit() {
    LIT="$(printf "$@"; printf X)"
    LIT="${LIT%X}"
}
run() {
    bash "$T" "$@" > "$W/.out" 2> "$W/.err"
    RC=$?
    OUT="$(cat "$W/.out"; printf X)"
    OUT="${OUT%X}"
    ERR="$(cat "$W/.err")"
}

export TPL_NAME=world TPL_APP=demo TPL_A=x TPL_B=y
unset TPL_PORT TPL_NOPE TPL_NOPE2 2>/dev/null || true

cat > "$W/main.tpl" <<'TPL'
Hello ${TPL_NAME}, welcome to $TPL_APP.
Port: ${TPL_PORT:-8080}
Missing: [${TPL_NOPE}] and [$TPL_NOPE2]
Literal dollar: $$ and $$TPL_NAME
Not a placeholder: $(date) `whoami` ${ not closed
Adjacent: ${TPL_A}${TPL_B}$TPL_A$TPL_B
Trailing name: $TPL_NAME.
TPL

want="$(cat <<'EXP'
Hello world, welcome to demo.
Port: 8080
Missing: [] and []
Literal dollar: $ and $TPL_NAME
Not a placeholder: $(date) `whoami` ${ not closed
Adjacent: xyxy
Trailing name: world.
EXP
)"
want="$want
"

run "$W/main.tpl"
eq "main rc" 0 "$RC"
eq "main stderr" "" "$ERR"
eq "main output" "$want" "$OUT"

# a vars file supplies names the environment does not have
{
    printf '# a comment\n'
    printf '\n'
    printf 'TPL_PORT = 9000\n'
    printf 'TPL_NAME=fromfile\n'
    printf 'TPL_EXTRA=  spaced value  \n'
} > "$W/vars.env"

run --vars "$W/vars.env" "$W/main.tpl"
eq "vars rc" 0 "$RC"
eq "vars output" "${want/Port: 8080/Port: 9000}" "$OUT"

printf '[${TPL_EXTRA}]\n' > "$W/extra.tpl"
run --vars "$W/vars.env" "$W/extra.tpl"
lit '[spaced value]\n'
eq "vars trimming" "$LIT" "$OUT"

# a template with nothing to substitute comes out byte for byte
printf 'plain text\nwith two lines\n' > "$W/plain.tpl"
run "$W/plain.tpl"
eq "plain rc" 0 "$RC"
lit 'plain text\nwith two lines\n'
eq "plain output" "$LIT" "$OUT"

# strict mode is quiet when everything resolves
printf '$TPL_NAME ${TPL_APP} ${TPL_MISSING:-fallback}\n' > "$W/strictok.tpl"
run --strict "$W/strictok.tpl"
eq "strict ok rc" 0 "$RC"
eq "strict ok stderr" "" "$ERR"
lit 'world demo fallback\n'
eq "strict ok output" "$LIT" "$OUT"

# defaults are literal text, not templates
printf '${TPL_MISSING:-a $TPL_NAME b $$ c}\n' > "$W/def.tpl"
run "$W/def.tpl"
lit 'a $TPL_NAME b $$ c\n'
eq "literal default" "$LIT" "$OUT"

# a value is never rescanned for placeholders
export TPL_SELF='$TPL_NAME and ${TPL_APP}'
printf '[${TPL_SELF}]\n' > "$W/self.tpl"
run "$W/self.tpl"
lit '[$TPL_NAME and ${TPL_APP}]\n'
eq "value not rescanned" "$LIT" "$OUT"

# nothing in the template is ever executed
printf 'a $(touch %s/EXECUTED) b `touch %s/EXECUTED2` c\n' "$W" "$W" > "$W/evil.tpl"
run "$W/evil.tpl"
eq "no execution rc" 0 "$RC"
lit 'a $(touch %s/EXECUTED) b `touch %s/EXECUTED2` c\n' "$W" "$W"
eq "no execution output" "$LIT" "$OUT"
if [ -e "$W/EXECUTED" ] || [ -e "$W/EXECUTED2" ]; then
    echo "FAIL the template was executed" >&2
    fails=$((fails + 1))
fi

exit $((fails > 0 ? 1 : 0))
