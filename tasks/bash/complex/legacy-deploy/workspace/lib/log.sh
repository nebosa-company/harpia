# Logging helpers shared by the deploy scripts.

log_info() {
    printf '%s\n' "$*"
}

log_err() {
    printf '%s\n' "$*" >&2
}
