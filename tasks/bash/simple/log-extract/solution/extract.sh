#!/usr/bin/env bash
# Access-log extractor.
set -u
export LC_ALL=C

usage() {
    echo "usage: extract.sh --top-paths N|--errors|--bytes|--methods LOGFILE" >&2
}

need_file() {
    if [ ! -f "$1" ]; then
        printf 'no such file: %s\n' "$1" >&2
        exit 1
    fi
}

TAB=$'\t'

main() {
    [ $# -ge 1 ] || { usage; exit 2; }
    local mode="$1"
    shift
    case "$mode" in
        --top-paths)
            [ $# -eq 2 ] || { usage; exit 2; }
            local n="$1" log="$2"
            case "$n" in
                ''|*[!0-9]*) usage; exit 2 ;;
            esac
            [ "$n" -ge 1 ] || { usage; exit 2; }
            need_file "$log"
            awk '
                /^[^ ]+ - - \[[^] ]+\] "[A-Z]+ [^" ]+ HTTP\/1\.1" [0-9]+ ([0-9]+|-)$/ &&
                $8 >= 200 && $8 <= 399 { c[$6]++ }
                END { for (p in c) printf "%d\t%s\n", c[p], p }
            ' "$log" | sort -t"$TAB" -k1,1nr -k2,2 | awk -v n="$n" 'NR <= n'
            ;;
        --errors)
            [ $# -eq 1 ] || { usage; exit 2; }
            need_file "$1"
            awk '
                /^[^ ]+ - - \[[^] ]+\] "[A-Z]+ [^" ]+ HTTP\/1\.1" [0-9]+ ([0-9]+|-)$/ &&
                $8 >= 400
            ' "$1"
            ;;
        --bytes)
            [ $# -eq 1 ] || { usage; exit 2; }
            need_file "$1"
            awk '
                /^[^ ]+ - - \[[^] ]+\] "[A-Z]+ [^" ]+ HTTP\/1\.1" [0-9]+ ([0-9]+|-)$/ {
                    if ($9 != "-") s += $9
                }
                END { printf "total: %d\n", s + 0 }
            ' "$1"
            ;;
        --methods)
            [ $# -eq 1 ] || { usage; exit 2; }
            need_file "$1"
            awk '
                /^[^ ]+ - - \[[^] ]+\] "[A-Z]+ [^" ]+ HTTP\/1\.1" [0-9]+ ([0-9]+|-)$/ {
                    c[substr($5, 2)]++
                }
                END { for (m in c) printf "%d\t%s\n", c[m], m }
            ' "$1" | sort -t"$TAB" -k1,1nr -k2,2
            ;;
        *)
            usage
            exit 2
            ;;
    esac
}

main "$@"
