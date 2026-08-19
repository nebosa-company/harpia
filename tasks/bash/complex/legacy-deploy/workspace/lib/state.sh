# Records what was deployed: an append-only history plus a pointer to the
# deployment that is live right now.

record_deploy() {
    local state="$1" id="$2" count="$3"
    local old

    old="$(cat "$state/history.tsv" 2>/dev/null)"
    {
        if [ -n "$old" ]; then
            printf '%s\n' "$old"
        fi
        printf '%s\t%s\n' "$id" "$count"
    } > "$state/history.tsv"

    printf '%s' "$id" > "$state/current.txt"
    sleep 0.05
    printf '\n' >> "$state/current.txt"
}
