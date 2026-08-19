# Time-series helpers for the nightly run.
#
# These were written when the inputs were a few hundred points long. They
# are now the slowest step in the pipeline.

running_total <- function(x) {
  out <- numeric(length(x))
  acc <- 0
  for (i in seq_along(x)) {
    acc <- acc + x[i]
    out[i] <- acc
  }
  out
}

pct_change <- function(x) {
  n <- length(x)
  out <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    if (i == 1L) {
      next
    }
    prev <- x[i - 1L]
    if (!is.na(prev) && prev == 0) {
      next
    }
    out[i] <- (x[i] - prev) / prev
  }
  out
}

rolling_mean <- function(x, k) {
  if (k < 1) {
    stop("k must be at least 1", call. = FALSE)
  }
  n <- length(x)
  out <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    if (i < k) {
      next
    }
    out[i] <- mean(x[(i - k + 1L):i])
  }
  out
}

zscore <- function(x) {
  n <- length(x)
  keep <- numeric(0)
  for (i in seq_len(n)) {
    if (!is.na(x[i])) {
      keep <- c(keep, x[i])
    }
  }
  if (length(keep) < 2L) {
    return(rep(NA_real_, n))
  }
  m <- mean(keep)
  s <- sd(keep)
  if (is.na(s) || s == 0) {
    return(rep(NA_real_, n))
  }
  out <- numeric(n)
  for (i in seq_len(n)) {
    out[i] <- (x[i] - m) / s
  }
  out
}
