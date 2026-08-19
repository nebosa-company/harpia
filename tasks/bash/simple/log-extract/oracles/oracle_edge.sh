#!/usr/bin/env bash
# hidden - edge cases
set -u
export LC_ALL=C
cd "$(dirname "$0")" || exit 1
T="$PWD/extract.sh"
[ -f "$T" ] || { echo "missing extract.sh" >&2; exit 1; }

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

printf '\n# a comment, not a log line\n' > "$W/messy.log"
cat >> "$W/messy.log" <<'EOF'
192.168.1.1 - - [2024-01-01T00:00:00Z] "GET /a HTTP/1.1" 200 10
192.168.1.2 - - [2024-01-01T00:00:01Z] "GET /b with space HTTP/1.1" 200 20
truncated line
192.168.1.3 - - [2024-01-01T00:00:02Z] "get /c HTTP/1.1" 200 30
192.168.1.4 - - [2024-01-01T00:00:03Z] "PUT /a HTTP/1.1" 201 -
192.168.1.5 - - [2024-01-01T00:00:04Z] "GET /b HTTP/1.1" 404 40
192.168.1.6 - - [2024-01-01T00:00:05Z] "GET /a HTTP/1.1" 500 50
EOF

# malformed and blank lines are dropped; "-" counts as zero
run --bytes "$W/messy.log"
eq "messy bytes" "total: 100" "$OUT"

# fewer distinct paths than N
run --top-paths 5 "$W/messy.log"
eq "messy top-paths" "$(printf '2\t/a')" "$OUT"

run --methods "$W/messy.log"
eq "messy methods" "$(printf '3\tGET\n1\tPUT')" "$OUT"

run --errors "$W/messy.log"
eq "messy errors" "$(printf '192.168.1.5 - - [2024-01-01T00:00:04Z] "GET /b HTTP/1.1" 404 40\n192.168.1.6 - - [2024-01-01T00:00:05Z] "GET /a HTTP/1.1" 500 50')" "$OUT"

# a log with no parsable line at all
printf 'nothing here\n\n' > "$W/empty.log"
run --bytes "$W/empty.log"
eq "empty bytes" "total: 0" "$OUT"
run --errors "$W/empty.log"
eq "empty errors rc" 0 "$RC"
eq "empty errors" "" "$OUT"

# equal counts break ties on the path, ascending
cat > "$W/ties.log" <<'EOF'
1.1.1.1 - - [2024-02-02T00:00:00Z] "GET /zeta HTTP/1.1" 200 1
1.1.1.1 - - [2024-02-02T00:00:01Z] "GET /alpha HTTP/1.1" 200 1
1.1.1.1 - - [2024-02-02T00:00:02Z] "GET /mid HTTP/1.1" 200 1
1.1.1.1 - - [2024-02-02T00:00:03Z] "GET /alpha HTTP/1.1" 200 1
1.1.1.1 - - [2024-02-02T00:00:04Z] "GET /zeta HTTP/1.1" 200 1
EOF
run --top-paths 3 "$W/ties.log"
eq "tie order" "$(printf '2\t/alpha\n2\t/zeta\n1\t/mid')" "$OUT"

# missing file
run --errors "$W/does-not-exist.log"
eq "missing file rc" 1 "$RC"
eq "missing file msg" "no such file: $W/does-not-exist.log" "$ERR"
eq "missing file stdout" "" "$OUT"

run --bytes "$W/does-not-exist.log"
eq "missing file rc (bytes)" 1 "$RC"

# usage errors
run --nope "$W/messy.log"
eq "unknown mode rc" 2 "$RC"
if [ -z "$ERR" ]; then
    echo "FAIL unknown mode wrote no usage line to stderr" >&2
    fails=$((fails + 1))
fi

run
eq "no args rc" 2 "$RC"

run --top-paths "$W/messy.log"
eq "missing N rc" 2 "$RC"

run --top-paths 0 "$W/messy.log"
eq "zero N rc" 2 "$RC"

run --top-paths -3 "$W/messy.log"
eq "negative N rc" 2 "$RC"

run --top-paths abc "$W/messy.log"
eq "non-numeric N rc" 2 "$RC"

run --bytes "$W/messy.log" extra
eq "extra arg rc" 2 "$RC"

exit $((fails > 0 ? 1 : 0))
