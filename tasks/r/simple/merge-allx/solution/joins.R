# Order-preserving joins built on match(), never on merge().

.keys <- function(df, by, side) {
  if (!(by %in% names(df))) {
    stop(sprintf("no key column %s in %s", by, side), call. = FALSE)
  }
  as.character(df[[by]])
}

left_join_df <- function(x, y, by) {
  kx <- .keys(x, by, "x")
  ky <- .keys(y, by, "y")

  present <- ky[!is.na(ky)]
  dup <- present[duplicated(present)]
  if (length(dup) > 0L) {
    stop(sprintf("duplicate keys in y: %s", dup[[1L]]), call. = FALSE)
  }

  idx <- match(kx, ky)
  idx[is.na(kx)] <- NA_integer_

  out <- x
  rownames(out) <- NULL
  for (nm in setdiff(names(y), by)) {
    target <- if (nm %in% names(x)) paste0(nm, ".y") else nm
    out[[target]] <- y[[nm]][idx]
  }
  out
}

anti_join_df <- function(x, y, by) {
  kx <- .keys(x, by, "x")
  ky <- .keys(y, by, "y")
  hit <- !is.na(kx) & (kx %in% ky[!is.na(ky)])
  out <- x[!hit, , drop = FALSE]
  rownames(out) <- NULL
  out
}

join_coverage <- function(x, y, by) {
  kx <- .keys(x, by, "x")
  ky <- .keys(y, by, "y")
  hit <- !is.na(kx) & (kx %in% ky[!is.na(ky)])
  list(
    matched = sum(hit),
    unmatched = sum(!hit),
    unmatched_keys = unique(kx[!hit])
  )
}
