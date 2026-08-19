# Frame helpers shared by the reporting scripts.
#
# Contract: each helper always returns a data frame, even when the result
# has a single column or no rows, and the returned frame is renumbered so
# its row names run 1..n.

pick <- function(df, cols) {
  df[, cols]
}

drop_cols <- function(df, cols) {
  df[, setdiff(names(df), cols)]
}

filter_rows <- function(df, keep) {
  df[keep, ]
}

head_frame <- function(df, n) {
  df[seq_len(min(n, nrow(df))), ]
}
