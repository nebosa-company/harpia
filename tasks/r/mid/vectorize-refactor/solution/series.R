# Time-series helpers for the nightly run, vectorised.
#
# `embed` gives the sliding windows as rows, which keeps a window holding
# an NA to itself instead of smearing it across every later window the way
# a cumulative-sum trick would.

running_total <- function(x) {
  as.numeric(cumsum(x))
}

pct_change <- function(x) {
  n <- length(x)
  if (n == 0L) {
    return(numeric(0))
  }
  prev <- c(NA_real_, as.numeric(x)[-n])
  out <- (as.numeric(x) - prev) / prev
  out[!is.na(prev) & prev == 0] <- NA_real_
  as.numeric(out)
}

.windowed <- function(x, k, f) {
  if (k < 1) {
    stop("k must be at least 1", call. = FALSE)
  }
  n <- length(x)
  out <- rep(NA_real_, n)
  if (n > 0L && k <= n) {
    out[k:n] <- as.numeric(f(embed(as.numeric(x), k)))
  }
  out
}

rolling_mean <- function(x, k) {
  .windowed(x, k, rowMeans)
}

rolling_max <- function(x, k) {
  .windowed(x, k, function(m) apply(m, 1L, max))
}

zscore <- function(x) {
  keep <- as.numeric(x)[!is.na(x)]
  if (length(keep) < 2L) {
    return(rep(NA_real_, length(x)))
  }
  s <- sd(keep)
  if (is.na(s) || s == 0) {
    return(rep(NA_real_, length(x)))
  }
  as.numeric((as.numeric(x) - mean(keep)) / s)
}

ewma <- function(x, alpha) {
  if (!is.numeric(alpha) || length(alpha) != 1L || is.na(alpha) ||
      alpha <= 0 || alpha > 1) {
    stop("alpha must be in (0, 1]", call. = FALSE)
  }
  v <- as.numeric(x)
  if (length(v) == 0L) {
    return(numeric(0))
  }
  as.numeric(Reduce(
    function(prev, cur) alpha * cur + (1 - alpha) * prev,
    v[-1L],
    accumulate = TRUE,
    init = v[[1L]]
  ))
}
