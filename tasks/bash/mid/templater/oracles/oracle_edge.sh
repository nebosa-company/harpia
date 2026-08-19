#!/usr/bin/env bash
# hidden - edge cases
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

export ZQ_SET=value ZQ_BLANK=

# strict mode names every undefined placeholder once, in order
printf '$ZQ_ZULU ${ZQ_ALPHA} $ZQ_ZULU ${ZQ_MIKE} ${ZQ_OK:-fine} $ZQ_SET\n' > "$W/strict.tpl"
run --strict "$W/strict.tpl"
eq "strict rc" 3 "$RC"
eq "strict stderr" "$(printf 'undefined: ZQ_ALPHA\nundefined: ZQ_MIKE\nundefined: ZQ_ZULU')" "$ERR"
eq "strict stdout" "" "$OUT"

# without --strict the same template just expands to empty strings
run "$W/strict.tpl"
eq "non-strict rc" 0 "$RC"
lit '    fine value\n'
eq "non-strict output" "$LIT" "$OUT"

# an environment variable set to the empty string counts as defined
printf '[$ZQ_BLANK]\n' > "$W/blank.tpl"
run --strict "$W/blank.tpl"
eq "empty env value rc" 0 "$RC"
lit '[]\n'
eq "empty env value" "$LIT" "$OUT"

# so does an empty value in the vars file
printf 'ZQ_FROMFILE=\n' > "$W/vars.env"
printf '[${ZQ_FROMFILE}]\n' > "$W/ff.tpl"
run --strict --vars "$W/vars.env" "$W/ff.tpl"
eq "empty file value rc" 0 "$RC"
lit '[]\n'
eq "empty file value" "$LIT" "$OUT"

# a template with no trailing newline keeps none
printf 'x=$ZQ_SET' > "$W/nonl.tpl"
run "$W/nonl.tpl"
eq "no trailing newline" "x=value" "$OUT"

# an empty template
: > "$W/empty.tpl"
run "$W/empty.tpl"
eq "empty template rc" 0 "$RC"
eq "empty template" "" "$OUT"

# malformed braces are literal
printf '${} ${1BAD} ${ZQ_SET B} ${ZQ_SET\n' > "$W/braces.tpl"
run "$W/braces.tpl"
eq "malformed braces rc" 0 "$RC"
lit '${} ${1BAD} ${ZQ_SET B} ${ZQ_SET\n'
eq "malformed braces" "$LIT" "$OUT"

# an unterminated ${ with no closing brace anywhere
printf 'only ${ here\n' > "$W/unterm.tpl"
run "$W/unterm.tpl"
lit 'only ${ here\n'
eq "unterminated" "$LIT" "$OUT"

# a lone dollar in every awkward position
printf '$1 $ $- $.$\n' > "$W/lone.tpl"
run "$W/lone.tpl"
lit '$1 $ $- $.$\n'
eq "lone dollars" "$LIT" "$OUT"

# three dollars in a row: one literal, then a placeholder
printf '$$$ZQ_SET\n' > "$W/three.tpl"
run "$W/three.tpl"
lit '$value\n'
eq "three dollars" "$LIT" "$OUT"

# four dollars are two literals
printf '$$$$ZQ_SET\n' > "$W/four.tpl"
run "$W/four.tpl"
lit '$$ZQ_SET\n'
eq "four dollars" "$LIT" "$OUT"

# a name stops at the first character that cannot continue it
printf '$ZQ_SET-tail $ZQ_SET.tail ${ZQ_SET}tail\n' > "$W/bound.tpl"
run "$W/bound.tpl"
lit 'value-tail value.tail valuetail\n'
eq "name boundaries" "$LIT" "$OUT"

# a default containing colons, dashes and spaces
printf '${ZQ_GONE:-a: b -- c}\n' > "$W/colon.tpl"
run "$W/colon.tpl"
lit 'a: b -- c\n'
eq "rich default" "$LIT" "$OUT"

# the environment beats the vars file
printf 'ZQ_SET=fromfile\n' > "$W/clash.env"
printf '$ZQ_SET\n' > "$W/clash.tpl"
run --vars "$W/clash.env" "$W/clash.tpl"
lit 'value\n'
eq "environment wins" "$LIT" "$OUT"

# missing files
run "$W/absent.tpl"
eq "missing template rc" 1 "$RC"
eq "missing template stderr" "no such file: $W/absent.tpl" "$ERR"
run --vars "$W/absent.env" "$W/clash.tpl"
eq "missing vars rc" 1 "$RC"
eq "missing vars stderr" "no such file: $W/absent.env" "$ERR"

# usage errors
run
eq "no template rc" 2 "$RC"
run --strict
eq "strict with no template rc" 2 "$RC"
run --vars
eq "dangling --vars rc" 2 "$RC"
run --bogus "$W/clash.tpl"
eq "unknown option rc" 2 "$RC"
run "$W/clash.tpl" "$W/lone.tpl"
eq "two templates rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
