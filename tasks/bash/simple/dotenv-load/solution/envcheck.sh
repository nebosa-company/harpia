#!/usr/bin/env bash
# Dotenv reader and requirement checker: reads the file as data, never runs it.
set -u
export LC_ALL=C

usage() {
    echo "usage: envcheck.sh --file F [--get NAME | --require A,B,C]" >&2
}

FILE=""
GET=""
HAS_GET=0
REQUIRE=""
HAS_REQ=0

while [ $# -gt 0 ]; do
    case "$1" in
        --file)    [ $# -ge 2 ] || { usage; exit 2; }; FILE="$2"; shift 2 ;;
        --get)     [ $# -ge 2 ] || { usage; exit 2; }; GET="$2"; HAS_GET=1; shift 2 ;;
        --require) [ $# -ge 2 ] || { usage; exit 2; }; REQUIRE="$2"; HAS_REQ=1; shift 2 ;;
        *)         usage; exit 2 ;;
    esac
done

[ -n "$FILE" ] || { usage; exit 2; }
[ $((HAS_GET + HAS_REQ)) -le 1 ] || { usage; exit 2; }
if [ ! -f "$FILE" ]; then
    printf 'no such file: %s\n' "$FILE" >&2
    exit 1
fi

declare -A VALS=()
ORDER=()

n=0
while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    body="$line"
    if [[ "$body" =~ ^[[:space:]]*export[[:space:]]+(.*)$ ]]; then
        body="${BASH_REMATCH[1]}"
    fi
    if [[ "$body" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        val="${BASH_REMATCH[2]}"
    else
        printf 'bad line %d: %s\n' "$n" "$line" >&2
        exit 3
    fi
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"
    if [ "${#val}" -ge 2 ]; then
        first="${val:0:1}"
        last="${val: -1}"
        if [ "$first" = "$last" ] && { [ "$first" = '"' ] || [ "$first" = "'" ]; }; then
            val="${val:1:${#val}-2}"
        fi
    fi
    if [ -z "${VALS[$key]+set}" ]; then
        ORDER+=("$key")
    fi
    VALS["$key"]="$val"
done < "$FILE"

if [ "$HAS_GET" -eq 1 ]; then
    if [ -z "${VALS[$GET]+set}" ]; then
        printf 'not set: %s\n' "$GET" >&2
        exit 4
    fi
    printf '%s\n' "${VALS[$GET]}"
    exit 0
fi

if [ "$HAS_REQ" -eq 1 ]; then
    missing=()
    IFS=',' read -r -a wanted <<< "$REQUIRE"
    for name in ${wanted[@]+"${wanted[@]}"}; do
        if [ -z "${VALS[$name]+set}" ] || [ -z "${VALS[$name]}" ]; then
            missing+=("$name")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        printf '%s\n' "${missing[@]}" | sort | while IFS= read -r m; do
            printf 'missing: %s\n' "$m" >&2
        done
        exit 5
    fi
    exit 0
fi

if [ ${#ORDER[@]} -gt 0 ]; then
    while IFS= read -r k; do
        printf '%s=%s\n' "$k" "${VALS[$k]}"
    done < <(printf '%s\n' "${ORDER[@]}" | sort)
fi
