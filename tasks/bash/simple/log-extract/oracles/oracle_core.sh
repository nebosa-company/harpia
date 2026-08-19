#!/usr/bin/env bash
# hidden - core behaviour
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

cat > "$W/access.log" <<'EOF'
10.0.0.1 - - [2024-10-10T13:55:36Z] "GET /index.html HTTP/1.1" 200 512
10.0.0.2 - - [2024-10-10T13:55:37Z] "GET /about HTTP/1.1" 200 100
10.0.0.1 - - [2024-10-10T13:55:38Z] "POST /api/login HTTP/1.1" 302 0
10.0.0.3 - - [2024-10-10T13:55:39Z] "GET /index.html HTTP/1.1" 200 512
10.0.0.4 - - [2024-10-10T13:55:40Z] "GET /missing HTTP/1.1" 404 -
10.0.0.5 - - [2024-10-10T13:55:41Z] "GET /index.html HTTP/1.1" 500 0
10.0.0.6 - - [2024-10-10T13:55:42Z] "DELETE /api/item/9 HTTP/1.1" 204 0
10.0.0.7 - - [2024-10-10T13:55:43Z] "GET /about HTTP/1.1" 304 0
EOF

run --top-paths 3 "$W/access.log"
eq "top-paths 3 rc" 0 "$RC"
eq "top-paths 3" "$(printf '2\t/about\n2\t/index.html\n1\t/api/item/9')" "$OUT"

run --top-paths 1 "$W/access.log"
eq "top-paths 1" "$(printf '2\t/about')" "$OUT"

run --errors "$W/access.log"
eq "errors rc" 0 "$RC"
eq "errors" "$(printf '10.0.0.4 - - [2024-10-10T13:55:40Z] "GET /missing HTTP/1.1" 404 -\n10.0.0.5 - - [2024-10-10T13:55:41Z] "GET /index.html HTTP/1.1" 500 0')" "$OUT"

run --bytes "$W/access.log"
eq "bytes rc" 0 "$RC"
eq "bytes" "total: 1124" "$OUT"

run --methods "$W/access.log"
eq "methods rc" 0 "$RC"
eq "methods" "$(printf '6\tGET\n1\tDELETE\n1\tPOST')" "$OUT"

exit $((fails > 0 ? 1 : 0))
