#!/usr/bin/env bash
# Release pipeline with an atomic symlink swap and rollback.
set -u
export LC_ALL=C

usage() {
    echo "usage: deploy.sh --root DIR release|rollback|list [options]" >&2
}

ROOT=""
ACTION=""
ID=""
ART=""
KEEP=""
HEALTH=""
HAS_HEALTH=0

while [ $# -gt 0 ]; do
    case "$1" in
        --root)     [ $# -ge 2 ] || { usage; exit 2; }; ROOT="$2"; shift 2 ;;
        --id)       [ $# -ge 2 ] || { usage; exit 2; }; ID="$2"; shift 2 ;;
        --artifact) [ $# -ge 2 ] || { usage; exit 2; }; ART="$2"; shift 2 ;;
        --keep)     [ $# -ge 2 ] || { usage; exit 2; }; KEEP="$2"; shift 2 ;;
        --health)   [ $# -ge 2 ] || { usage; exit 2; }; HEALTH="$2"; HAS_HEALTH=1; shift 2 ;;
        -*)         usage; exit 2 ;;
        *)          [ -z "$ACTION" ] || { usage; exit 2; }; ACTION="$1"; shift ;;
    esac
done

[ -n "$ROOT" ] || { usage; exit 2; }
case "$ACTION" in
    release|rollback|list) ;;
    *) usage; exit 2 ;;
esac

ROOT="${ROOT%/}"

current_id() {
    [ -L "$ROOT/current" ] || return 1
    local t
    t="$(readlink -- "$ROOT/current")" || return 1
    printf '%s' "${t#releases/}"
}

list_ids() {
    [ -d "$ROOT/releases" ] || return 0
    find "$ROOT/releases" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

swap() {
    local tmp="$ROOT/.current.$$"
    rm -f -- "$tmp"
    ln -s "releases/$1" "$tmp" || return 1
    mv -T -- "$tmp" "$ROOT/current" || { rm -f -- "$tmp"; return 1; }
    return 0
}

case "$ACTION" in
    release)
        [ -n "$ID" ] || { usage; exit 2; }
        [[ "$ID" =~ ^[A-Za-z0-9._-]+$ ]] || { usage; exit 2; }
        [ -n "$ART" ] || { usage; exit 2; }
        if [ -n "$KEEP" ]; then
            case "$KEEP" in
                ''|*[!0-9]*) usage; exit 2 ;;
            esac
            [ "$KEEP" -ge 1 ] || { usage; exit 2; }
        fi
        if [ ! -f "$ART" ]; then
            printf 'no such file: %s\n' "$ART" >&2
            exit 1
        fi
        mkdir -p -- "$ROOT/releases" || exit 1
        NEW="$ROOT/releases/$ID"
        if [ -e "$NEW" ]; then
            printf 'duplicate release: %s\n' "$ID" >&2
            exit 4
        fi
        mkdir -p -- "$NEW" || exit 1
        if ! tar -xf "$ART" -C "$NEW" > /dev/null 2>&1; then
            rm -rf -- "$NEW"
            printf 'extract failed: %s\n' "$ID" >&2
            exit 3
        fi
        if [ "$HAS_HEALTH" -eq 1 ]; then
            if ! ( cd "$NEW" && bash -c "$HEALTH" ) > /dev/null 2>&1; then
                rm -rf -- "$NEW"
                printf 'health check failed: %s\n' "$ID" >&2
                exit 5
            fi
        fi
        swap "$ID" || exit 1
        printf 'released: %s\n' "$ID"
        if [ -n "$KEEP" ]; then
            ids=()
            while IFS= read -r i; do ids+=("$i"); done < <(list_ids)
            n=${#ids[@]}
            for i in ${ids[@]+"${ids[@]}"}; do
                if [ "$n" -le "$KEEP" ]; then
                    break
                fi
                if [ "$i" = "$ID" ]; then
                    continue
                fi
                rm -rf -- "$ROOT/releases/$i"
                printf 'pruned: %s\n' "$i"
                n=$((n - 1))
            done
        fi
        exit 0
        ;;
    rollback)
        if ! cur="$(current_id)"; then
            printf 'nothing to roll back\n' >&2
            exit 6
        fi
        target=""
        while IFS= read -r i; do
            if [ "$i" = "$cur" ]; then
                continue
            fi
            target="$i"
        done < <(list_ids)
        if [ -z "$target" ]; then
            printf 'nothing to roll back\n' >&2
            exit 6
        fi
        swap "$target" || exit 1
        printf 'rolled back to: %s\n' "$target"
        exit 0
        ;;
    list)
        cur="$(current_id || true)"
        while IFS= read -r i; do
            if [ "$i" = "$cur" ]; then
                printf '%s *\n' "$i"
            else
                printf '%s\n' "$i"
            fi
        done < <(list_ids)
        exit 0
        ;;
esac
