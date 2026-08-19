#!/usr/bin/env bash
# hidden - edge cases
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/csvsum.sh"
[ -f "$T" ] || { echo "missing csvsum.sh" >&2; exit 1; }

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

cat > "$W/messy.csv" <<'EOF'
name,amount,note
alpha, -5.25 ,ok

beta,10,ok
short,row
gamma,0.75,ok
delta,-0.75,
EOF

run --sum amount "$W/messy.csv"
eq "messy rc" 0 "$RC"
eq "messy sum" "4.75" "$OUT"
eq "messy skipped" "skipped: 1" "$ERR"

run --group-by note --sum amount "$W/messy.csv"
eq "empty group key" "$(printf '\t-0.75\nok\t5.50')" "$OUT"

run --where 'note=' --sum amount "$W/messy.csv"
eq "where empty value" "-0.75" "$OUT"

run --where 'note=nothing' --sum amount "$W/messy.csv"
eq "where matches nothing rc" 0 "$RC"
eq "where matches nothing" "0.00" "$OUT"

run --where 'note=nothing' --group-by name --sum amount "$W/messy.csv"
eq "empty group rc" 0 "$RC"
eq "empty group" "" "$OUT"

# a value containing '=' only splits on the first one
cat > "$W/eq.csv" <<'EOF'
key,n
a=b=c,4
plain,1
EOF
run --where 'key=a=b=c' --sum n "$W/eq.csv"
eq "value with equals" "4.00" "$OUT"

# header only
printf 'a,b\n' > "$W/header.csv"
run --sum b "$W/header.csv"
eq "header only rc" 0 "$RC"
eq "header only" "0.00" "$OUT"

# non-numeric value in the summed column
cat > "$W/bad.csv" <<'EOF'
k,v
a,1
b,oops
c,2
EOF
run --sum v "$W/bad.csv"
eq "bad number rc" 3 "$RC"
eq "bad number stderr" "bad number: oops on line 3" "$ERR"
eq "bad number stdout" "" "$OUT"

# a filtered-out bad value is never inspected
run --where 'k=a' --sum v "$W/bad.csv"
eq "filtered bad rc" 0 "$RC"
eq "filtered bad sum" "1.00" "$OUT"

# exponent notation is not a number here
printf 'k,v\nx,1e3\n' > "$W/exp.csv"
run --sum v "$W/exp.csv"
eq "exponent rc" 3 "$RC"

# unknown columns
run --sum nope "$W/messy.csv"
eq "unknown sum col rc" 4 "$RC"
eq "unknown sum col stderr" "no such column: nope" "$ERR"
run --sum amount --group-by nope "$W/messy.csv"
eq "unknown group col rc" 4 "$RC"
run --sum amount --where 'nope=1' "$W/messy.csv"
eq "unknown where col rc" 4 "$RC"

# file and usage errors
run --sum amount "$W/absent.csv"
eq "missing file rc" 1 "$RC"
eq "missing file stderr" "no such file: $W/absent.csv" "$ERR"

run "$W/messy.csv"
eq "no --sum rc" 2 "$RC"
run --sum amount
eq "no file rc" 2 "$RC"
run --sum amount --where noequals "$W/messy.csv"
eq "bad --where rc" 2 "$RC"
run --sum amount --bogus "$W/messy.csv"
eq "unknown option rc" 2 "$RC"
run --sum
eq "dangling --sum rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
