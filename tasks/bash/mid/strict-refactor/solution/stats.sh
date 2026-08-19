#!/usr/bin/env bash
# Column statistics over a tab-separated file.
set -euo pipefail
export LC_ALL=C

usage() {
    echo "usage: stats.sh --field N FILE" >&2
}

read_records() {
    local file="$1"
    if [ ! -f "$file" ]; then
        printf 'no such file: %s\n' "$file" >&2
        return 1
    fi
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^[[:blank:]]*(.*[^[:blank:]])?[[:blank:]]*$ ]]; then
            line="${BASH_REMATCH[1]}"
        fi
        if [ -z "$line" ]; then
            continue
        fi
        case "$line" in
            '#'*) continue ;;
        esac
        printf '%s\n' "$line"
    done < "$file"
    return 0
}

field() {
    local n="${1-}"
    case "$n" in
        ''|*[!0-9]*)
            printf 'bad field: %s\n' "$n" >&2
            return 2
            ;;
    esac
    if [ "$n" -lt 1 ]; then
        printf 'bad field: %s\n' "$n" >&2
        return 2
    fi
    awk -F'\t' -v n="$n" '{ print (NF >= n ? $n : "") }'
}

summarize() {
    local out rc
    out="$(awk '
        {
            if ($0 !~ /^-?[0-9]+$/) {
                printf "not a number: %s\n", $0 > "/dev/stderr"
                bad = 3
                exit 3
            }
            n++
            s += $0
            if (n == 1 || $0 + 0 < mn) mn = $0 + 0
            if (n == 1 || $0 + 0 > mx) mx = $0 + 0
        }
        END {
            if (bad) exit bad
            if (n == 0) exit 1
            printf "count=%d sum=%d min=%d max=%d mean=%.2f\n", n, s, mn, mx, s / n
        }
    ')" || { rc=$?; return "$rc"; }
    printf '%s\n' "$out"
    return 0
}

main() {
    local fieldno="" file="" seen_file=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --field)
                [ $# -ge 2 ] || { usage; return 2; }
                fieldno="$2"
                shift 2
                ;;
            -*)
                usage
                return 2
                ;;
            *)
                [ "$seen_file" -eq 0 ] || { usage; return 2; }
                file="$1"
                seen_file=1
                shift
                ;;
        esac
    done
    [ -n "$fieldno" ] || { usage; return 2; }
    [ "$seen_file" -eq 1 ] || { usage; return 2; }

    case "$fieldno" in
        ''|*[!0-9]*) printf 'bad field: %s\n' "$fieldno" >&2; return 2 ;;
    esac
    if [ "$fieldno" -lt 1 ]; then
        printf 'bad field: %s\n' "$fieldno" >&2
        return 2
    fi

    local records cols summary rc=0
    if ! records="$(read_records "$file")"; then
        return 1
    fi
    if [ -z "$records" ]; then
        printf 'no records\n' >&2
        return 4
    fi
    # The trailing X keeps empty last fields from being eaten by $( ).
    cols="$(printf '%s\n' "$records" | field "$fieldno"; printf X)"
    cols="${cols%X}"
    summary="$(printf '%s' "$cols" | summarize)" || rc=$?
    if [ "$rc" -eq 0 ]; then
        printf '%s\n' "$summary"
        return 0
    fi
    if [ "$rc" -eq 1 ]; then
        printf 'no records\n' >&2
        return 4
    fi
    return "$rc"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
