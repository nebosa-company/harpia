#!/usr/bin/env bash
# Prefix every regular file in a directory, hostile names included.
set -u
export LC_ALL=C

usage() {
    echo "usage: rename.sh [--dry-run] --prefix P DIR" >&2
}

DRY=0
PREFIX=""
DIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY=1
            shift
            ;;
        --prefix)
            [ $# -ge 2 ] || { usage; exit 2; }
            PREFIX="$2"
            shift 2
            ;;
        --prefix=*)
            PREFIX="${1#--prefix=}"
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            usage
            exit 2
            ;;
        *)
            [ -z "$DIR" ] || { usage; exit 2; }
            DIR="$1"
            shift
            ;;
    esac
done
if [ $# -gt 0 ]; then
    [ -z "$DIR" ] || { usage; exit 2; }
    DIR="$1"
    shift
    [ $# -eq 0 ] || { usage; exit 2; }
fi

[ -n "$PREFIX" ] || { usage; exit 2; }
[ -n "$DIR" ] || { usage; exit 2; }
if [ ! -d "$DIR" ]; then
    printf 'not a directory: %s\n' "$DIR" >&2
    exit 1
fi

names=()
while IFS= read -r -d '' n; do
    case "$n" in
        "$PREFIX"*) continue ;;
    esac
    names+=("$n")
done < <(find "$DIR" -mindepth 1 -maxdepth 1 -type f -printf '%f\0' | sort -z)

collisions=()
for n in ${names[@]+"${names[@]}"}; do
    if [ -e "$DIR/$PREFIX$n" ] || [ -L "$DIR/$PREFIX$n" ]; then
        collisions+=("$PREFIX$n")
    fi
done
if [ ${#collisions[@]} -gt 0 ]; then
    printf '%s\0' "${collisions[@]}" | sort -z | while IFS= read -r -d '' c; do
        printf 'exists: %s\n' "$c" >&2
    done
    exit 3
fi

count=0
for n in ${names[@]+"${names[@]}"}; do
    if [ "$DRY" -eq 1 ]; then
        printf '%s -> %s\n' "$n" "$PREFIX$n"
    else
        mv -- "$DIR/$n" "$DIR/$PREFIX$n" || exit 1
    fi
    count=$((count + 1))
done

printf 'renamed: %d\n' "$count"
