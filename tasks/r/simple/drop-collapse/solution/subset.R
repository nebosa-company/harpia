# Frame helpers shared by the reporting scripts.
#
# Contract: each helper always returns a data frame, even when the result
# has a single column or no rows, and the returned frame is renumbered so
# its row names run 1..n.

.renumber <- function(df) {
  rownames(df) <- NULL
  df
}

pick <- function(df, cols) {
  .renumber(df[, cols, drop = FALSE])
}

drop_cols <- function(df, cols) {
  .renumber(df[, setdiff(names(df), cols), drop = FALSE])
}

filter_rows <- function(df, keep) {
  keep <- as.logical(keep)
  keep[is.na(keep)] <- FALSE
  .renumber(df[keep, , drop = FALSE])
}

head_frame <- function(df, n) {
  k <- max(0L, min(as.integer(n), nrow(df)))
  .renumber(df[seq_len(k), , drop = FALSE])
}
