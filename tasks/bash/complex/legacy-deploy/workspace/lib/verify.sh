# Runs the post-deployment verification command inside the deployed tree,
# keeping a copy of its output in the state directory.

run_verify() {
    local dest="$1" cmd="$2" logfile="$3"
    ( cd "$dest" && bash -c "$cmd" ) 2>&1 | tee -a "$logfile" > /dev/null
}
