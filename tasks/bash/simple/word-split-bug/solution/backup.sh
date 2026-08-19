#!/usr/bin/env bash
# Copy the flat contents of one directory into another.
set -u

usage() {
    echo "usage: backup.sh SRC DEST" >&2
}

if [ $# -ne 2 ]; then
    usage
    exit 2
fi

SRC="$1"
DEST="$2"

if [ ! -d "$SRC" ]; then
    printf 'no such directory: %s\n' "$SRC" >&2
    exit 1
fi

mkdir -p -- "$DEST" || exit 1

count=0
while IFS= read -r -d '' f; do
    cp -- "$f" "$DEST/${f##*/}" || exit 1
    count=$((count + 1))
done < <(find "$SRC" -mindepth 1 -maxdepth 1 -type f -print0)

printf 'copied: %d\n' "$count"
