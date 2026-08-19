#!/usr/bin/env bash
# hidden - core behaviour
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

cat > "$W/sales.csv" <<'EOF'
region,product,units,revenue
east,widget,3,10.50
west,widget,2,7.25
east,gadget,5,100.00
north,widget,1, 2.50
west,gadget,4,20.00
EOF

run --sum revenue "$W/sales.csv"
eq "sum revenue rc" 0 "$RC"
eq "sum revenue" "140.25" "$OUT"
eq "sum revenue stderr" "" "$ERR"

run --sum units "$W/sales.csv"
eq "sum units" "15.00" "$OUT"

run --group-by region --sum revenue "$W/sales.csv"
eq "group region rc" 0 "$RC"
eq "group region" "$(printf 'east\t110.50\nnorth\t2.50\nwest\t27.25')" "$OUT"

run --group-by product --sum units "$W/sales.csv"
eq "group product" "$(printf 'gadget\t9.00\nwidget\t6.00')" "$OUT"

run --where product=widget --sum revenue "$W/sales.csv"
eq "where rc" 0 "$RC"
eq "where" "20.25" "$OUT"

run --where product=widget --group-by region --sum units "$W/sales.csv"
eq "where + group" "$(printf 'east\t3.00\nnorth\t1.00\nwest\t2.00')" "$OUT"

# option order is free
run "$W/sales.csv" --sum revenue --group-by region
eq "options after file" "$(printf 'east\t110.50\nnorth\t2.50\nwest\t27.25')" "$OUT"

exit $((fails > 0 ? 1 : 0))
