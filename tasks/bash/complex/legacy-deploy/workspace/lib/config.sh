# Defaults read from config/app.conf.
#
# Recognised keys: state_dir, verify. Anything else is ignored, so the file
# can carry settings for the other tools on the box as well.

load_config() {
    STATE_DIR="state"
    VERIFY_CMD=""
    [ -f "$1" ] || return 0
    local line key val
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|'#'*) continue ;;
            *=*) ;;
            *) continue ;;
        esac
        key="${line%%=*}"
        val="${line#*=}"
        case "$key" in
            state_dir) STATE_DIR="$val" ;;
            verify)    VERIFY_CMD="$val" ;;
        esac
    done < "$1"
    return 0
}
