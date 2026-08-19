# Survey level handling: relevelling by label, and label-aware numbers.

set_order <- function(x, order) {
  factor(as.character(x), levels = order, ordered = TRUE)
}

level_counts <- function(f) {
  if (!is.factor(f)) {
    stop("expected a factor", call. = FALSE)
  }
  data.frame(
    level = levels(f),
    count = as.integer(table(f)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

numeric_codes <- function(f) {
  if (!is.factor(f)) {
    stop("expected a factor", call. = FALSE)
  }
  labs <- levels(f)
  vals <- suppressWarnings(as.numeric(labs))
  bad <- which(is.na(vals))
  if (length(bad) > 0L) {
    stop(sprintf("non-numeric level: %s", labs[bad[1L]]), call. = FALSE)
  }
  as.double(vals[as.integer(f)])
}
