# Records what was deployed: an append-only history plus a pointer to the
# deployment that is live right now. Both updates happen under one exclusive
# lock, and the pointer is put in place by a rename, so a concurrent
# deployment can neither lose a history entry nor observe half an id.

record_deploy() {
    local state="$1" id="$2" count="$3"
    local tmp

    exec 9> "$state/.lock" || return 1
    flock -x 9 || { exec 9>&-; return 1; }

    printf '%s\t%s\n' "$id" "$count" >> "$state/history.tsv"

    tmp="$state/.current.$$"
    printf '%s\n' "$id" > "$tmp" || { flock -u 9; exec 9>&-; return 1; }
    mv -- "$tmp" "$state/current.txt" || { rm -f -- "$tmp"; flock -u 9; exec 9>&-; return 1; }

    flock -u 9
    exec 9>&-
    return 0
}
