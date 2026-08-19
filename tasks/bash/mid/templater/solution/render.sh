#!/usr/bin/env bash
# Template expander that treats its input strictly as data.
set -u
export LC_ALL=C

usage() {
    echo "usage: render.sh [--strict] [--vars FILE] TEMPLATE" >&2
}

STRICT=0
VARS=""
TEMPLATE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --strict) STRICT=1; shift ;;
        --vars)   [ $# -ge 2 ] || { usage; exit 2; }; VARS="$2"; shift 2 ;;
        --)       shift ;;
        -*)       usage; exit 2 ;;
        *)        [ -z "$TEMPLATE" ] || { usage; exit 2; }; TEMPLATE="$1"; shift ;;
    esac
done

[ -n "$TEMPLATE" ] || { usage; exit 2; }
if [ ! -f "$TEMPLATE" ]; then
    printf 'no such file: %s\n' "$TEMPLATE" >&2
    exit 1
fi
if [ -n "$VARS" ] && [ ! -f "$VARS" ]; then
    printf 'no such file: %s\n' "$VARS" >&2
    exit 1
fi

# A snapshot of the real environment, so the script's own variables are
# never visible to the template.
declare -A ENVV=()
while IFS= read -r -d '' kv; do
    case "$kv" in
        *=*) ENVV["${kv%%=*}"]="${kv#*=}" ;;
    esac
done < <(env -0)

declare -A FILEV=()
if [ -n "$VARS" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        case "$line" in
            *=*) ;;
            *) continue ;;
        esac
        k="${line%%=*}"
        v="${line#*=}"
        k="${k#"${k%%[![:space:]]*}"}"
        k="${k%"${k##*[![:space:]]}"}"
        v="${v#"${v%%[![:space:]]*}"}"
        v="${v%"${v##*[![:space:]]}"}"
        [ -n "$k" ] && FILEV["$k"]="$v"
    done < "$VARS"
fi

content="$(cat -- "$TEMPLATE"; printf X)"
content="${content%X}"

declare -A UNDEF=()
out=""
rest="$content"

emit_name() {
    local n="$1" have_def="$2" def="$3"
    if [ -n "${ENVV[$n]+set}" ]; then
        out+="${ENVV[$n]}"
    elif [ -n "${FILEV[$n]+set}" ]; then
        out+="${FILEV[$n]}"
    elif [ "$have_def" -eq 1 ]; then
        out+="$def"
    else
        UNDEF["$n"]=1
    fi
}

while [ -n "$rest" ]; do
    pre="${rest%%\$*}"
    if [ "$pre" = "$rest" ]; then
        out+="$rest"
        break
    fi
    out+="$pre"
    rest="${rest:${#pre}}"
    c="${rest:1:1}"
    case "$c" in
        '$')
            out+='$'
            rest="${rest:2}"
            ;;
        '{')
            inner="${rest:2}"
            if [[ "$inner" == *'}'* ]]; then
                spec="${inner%%\}*}"
                after="${inner:$((${#spec} + 1))}"
                if [[ "$spec" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                    emit_name "$spec" 0 ""
                    rest="$after"
                elif [[ "$spec" =~ ^([A-Za-z_][A-Za-z0-9_]*):-(.*)$ ]]; then
                    emit_name "${BASH_REMATCH[1]}" 1 "${BASH_REMATCH[2]}"
                    rest="$after"
                else
                    out+='${'
                    rest="${rest:2}"
                fi
            else
                out+='${'
                rest="${rest:2}"
            fi
            ;;
        [A-Za-z_])
            tail="${rest:1}"
            [[ "$tail" =~ ^[A-Za-z_][A-Za-z0-9_]* ]]
            n="${BASH_REMATCH[0]}"
            emit_name "$n" 0 ""
            rest="${rest:$((1 + ${#n}))}"
            ;;
        *)
            out+='$'
            rest="${rest:1}"
            ;;
    esac
done

if [ "$STRICT" -eq 1 ] && [ ${#UNDEF[@]} -gt 0 ]; then
    printf '%s\n' "${!UNDEF[@]}" | sort | while IFS= read -r n; do
        printf 'undefined: %s\n' "$n" >&2
    done
    exit 3
fi

printf '%s' "$out"
