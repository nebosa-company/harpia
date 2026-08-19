#!/usr/bin/env bash
# Record-store CLI built on getopts.
set -u
export LC_ALL=C

USAGE="usage: tool.sh [-C DIR] [-v] [-h] add|list|get|remove [options]"
usage() { printf '%s\n' "$USAGE" >&2; }

TAB=$'\t'
DIR="."
VERBOSE=0

while getopts ":C:vh" opt; do
    case "$opt" in
        C) DIR="$OPTARG" ;;
        v) VERBOSE=1 ;;
        h) printf '%s\n' "$USAGE"; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

[ $# -ge 1 ] || { usage; exit 2; }
SUB="$1"
shift

STORE="$DIR/records.tsv"
if [ "$VERBOSE" -eq 1 ]; then
    printf 'store: %s\n' "$STORE" >&2
fi

valid_name() { [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]]; }
exists() {
    [ -f "$STORE" ] || return 1
    awk -F'\t' -v n="$1" '$1 == n { f = 1 } END { exit !f }' "$STORE"
}

NAME=""
VALUE=""
TAG=""
HAS_NAME=0
HAS_VALUE=0
HAS_TAG=0
OPTIND=1

case "$SUB" in
    add)
        while getopts ":n:V:t:" o; do
            case "$o" in
                n) NAME="$OPTARG"; HAS_NAME=1 ;;
                V) VALUE="$OPTARG"; HAS_VALUE=1 ;;
                t) TAG="$OPTARG"; HAS_TAG=1 ;;
                *) usage; exit 2 ;;
            esac
        done
        shift $((OPTIND - 1))
        [ $# -eq 0 ] || { usage; exit 2; }
        [ "$HAS_NAME" -eq 1 ] || { usage; exit 2; }
        [ "$HAS_VALUE" -eq 1 ] || { usage; exit 2; }
        valid_name "$NAME" || { usage; exit 2; }
        [ "$HAS_TAG" -eq 1 ] || TAG="-"
        mkdir -p -- "$DIR" || exit 1
        if exists "$NAME"; then
            printf 'duplicate: %s\n' "$NAME" >&2
            exit 4
        fi
        printf '%s\t%s\t%s\n' "$NAME" "$VALUE" "$TAG" >> "$STORE"
        printf 'added: %s\n' "$NAME"
        ;;
    list)
        while getopts ":t:" o; do
            case "$o" in
                t) TAG="$OPTARG"; HAS_TAG=1 ;;
                *) usage; exit 2 ;;
            esac
        done
        shift $((OPTIND - 1))
        [ $# -eq 0 ] || { usage; exit 2; }
        [ -f "$STORE" ] || exit 0
        if [ "$HAS_TAG" -eq 1 ]; then
            awk -F'\t' -v t="$TAG" '$3 == t' "$STORE" | sort -t"$TAB" -k1,1
        else
            sort -t"$TAB" -k1,1 "$STORE"
        fi
        ;;
    get)
        while getopts ":n:" o; do
            case "$o" in
                n) NAME="$OPTARG"; HAS_NAME=1 ;;
                *) usage; exit 2 ;;
            esac
        done
        shift $((OPTIND - 1))
        [ $# -eq 0 ] || { usage; exit 2; }
        [ "$HAS_NAME" -eq 1 ] || { usage; exit 2; }
        valid_name "$NAME" || { usage; exit 2; }
        if ! exists "$NAME"; then
            printf 'not found: %s\n' "$NAME" >&2
            exit 5
        fi
        awk -F'\t' -v n="$NAME" '$1 == n { print $2; exit }' "$STORE"
        ;;
    remove)
        while getopts ":n:" o; do
            case "$o" in
                n) NAME="$OPTARG"; HAS_NAME=1 ;;
                *) usage; exit 2 ;;
            esac
        done
        shift $((OPTIND - 1))
        [ $# -eq 0 ] || { usage; exit 2; }
        [ "$HAS_NAME" -eq 1 ] || { usage; exit 2; }
        valid_name "$NAME" || { usage; exit 2; }
        if ! exists "$NAME"; then
            printf 'not found: %s\n' "$NAME" >&2
            exit 5
        fi
        tmp="$STORE.tmp.$$"
        awk -F'\t' -v n="$NAME" '$1 != n' "$STORE" > "$tmp" || { rm -f -- "$tmp"; exit 1; }
        mv -- "$tmp" "$STORE" || exit 1
        printf 'removed: %s\n' "$NAME"
        ;;
    *)
        usage
        exit 2
        ;;
esac
