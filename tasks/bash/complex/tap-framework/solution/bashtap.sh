#!/usr/bin/env bash
# Miniature TAP 13 test runner.
set -u
export LC_ALL=C

usage() {
    echo "usage: bashtap.sh [--verbose] FILE..." >&2
}

VERBOSE=0
FILES=()
while [ $# -gt 0 ]; do
    case "$1" in
        --verbose) VERBOSE=1; shift ;;
        --)        shift; FILES+=("$@"); break ;;
        -*)        usage; exit 2 ;;
        *)         FILES+=("$1"); shift ;;
    esac
done

[ ${#FILES[@]} -ge 1 ] || { usage; exit 2; }
for f in "${FILES[@]}"; do
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then
        printf 'cannot read: %s\n' "$f" >&2
        exit 3
    fi
done

STATEDIR="$(mktemp -d)"
trap 'rm -rf "$STATEDIR"' EXIT
TAP_STATE="$STATEDIR/state"

# --- helpers the test files may call ---------------------------------------

assert_eq() {
    local expected="${1-}" actual="${2-}" msg="${3-}"
    if [ "$expected" = "$actual" ]; then
        return 0
    fi
    if [ -z "$msg" ]; then
        msg="expected [$expected] but got [$actual]"
    fi
    printf 'FAIL %s\n' "$msg" >> "$TAP_STATE"
    return 1
}

assert_ok() {
    if "$@"; then
        return 0
    fi
    printf 'FAIL command failed: %s\n' "$*" >> "$TAP_STATE"
    return 1
}

assert_fail() {
    if "$@"; then
        printf 'FAIL command unexpectedly succeeded: %s\n' "$*" >> "$TAP_STATE"
        return 1
    fi
    return 0
}

skip() {
    printf 'SKIP %s\n' "${1-}" >> "$TAP_STATE"
    exit 90
}

todo() {
    printf 'TODO %s\n' "${1-}" >> "$TAP_STATE"
}

bail() {
    printf 'BAIL %s\n' "${1-}" >> "$TAP_STATE"
    exit 91
}

# --- discovery --------------------------------------------------------------

list_tests() {
    sed -n -E 's/^[[:space:]]*(function[[:space:]]+)?(test_[A-Za-z0-9_]*)[[:space:]]*\(\).*$/\2/p' "$1"
}

total=0
for f in "${FILES[@]}"; do
    n="$(list_tests "$f" | wc -l)"
    total=$((total + n))
done

printf 'TAP version 13\n'
printf '1..%d\n' "$total"

# --- running ----------------------------------------------------------------

num=0
failed=0
bailed=0

for f in "${FILES[@]}"; do
    if [ "$VERBOSE" -eq 1 ]; then
        printf '# running %s\n' "$f"
    fi
    while IFS= read -r name; do
        num=$((num + 1))
        : > "$TAP_STATE"
        (
            source "$f"
            "$name"
        ) > /dev/null 2>&1
        rc=$?

        display="${name#test_}"
        display="${display//_/ }"

        if [ "$rc" -eq 90 ]; then
            reason="$(grep -m1 '^SKIP ' "$TAP_STATE" | cut -c6-)"
            printf 'ok %d - %s # SKIP %s\n' "$num" "$display" "$reason"
            continue
        fi
        if [ "$rc" -eq 91 ]; then
            reason="$(grep -m1 '^BAIL ' "$TAP_STATE" | cut -c6-)"
            printf 'not ok %d - %s\n' "$num" "$display"
            printf '# %s\n' "$reason"
            printf 'Bail out! %s\n' "$reason"
            bailed=1
            break
        fi

        istodo=0
        todoreason=""
        if grep -q '^TODO ' "$TAP_STATE"; then
            istodo=1
            todoreason="$(grep -m1 '^TODO ' "$TAP_STATE" | cut -c6-)"
        fi

        diags=()
        while IFS= read -r d; do
            diags+=("$d")
        done < <(grep '^FAIL ' "$TAP_STATE" | cut -c6-)

        ok=1
        if [ ${#diags[@]} -gt 0 ]; then
            ok=0
        elif [ "$rc" -ne 0 ]; then
            ok=0
            diags+=("test returned $rc")
        fi

        if [ "$ok" -eq 1 ]; then
            if [ "$istodo" -eq 1 ]; then
                printf 'ok %d - %s # TODO %s\n' "$num" "$display" "$todoreason"
            else
                printf 'ok %d - %s\n' "$num" "$display"
            fi
        else
            if [ "$istodo" -eq 1 ]; then
                printf 'not ok %d - %s # TODO %s\n' "$num" "$display" "$todoreason"
            else
                printf 'not ok %d - %s\n' "$num" "$display"
                failed=1
            fi
            for d in "${diags[@]}"; do
                printf '# %s\n' "$d"
            done
        fi
    done < <(list_tests "$f")
    if [ "$bailed" -eq 1 ]; then
        break
    fi
done

if [ "$bailed" -eq 1 ]; then
    exit 4
fi
if [ "$failed" -eq 1 ]; then
    exit 1
fi
exit 0
