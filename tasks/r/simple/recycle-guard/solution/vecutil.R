# Recycling-safe vector utilities. Recycling is allowed only where it is
# unambiguous: equal lengths, or one operand of length 1.

pairwise <- function(x, y, f) {
  nx <- length(x)
  ny <- length(y)
  ok <- (nx == ny) || (nx == 1L && ny > 1L) || (ny == 1L && nx > 1L)
  if (!ok) {
    stop(sprintf("length mismatch: %d vs %d", nx, ny), call. = FALSE)
  }
  res <- unname(f(x, y))
  nm <- if (nx >= ny) names(x) else names(y)
  if (!is.null(nm)) {
    names(res) <- nm
  }
  res
}

safe_add <- function(x, y) {
  pairwise(x, y, `+`)
}

recycle_strict <- function(x, n) {
  nx <- length(x)
  if (n == 0L) {
    return(x[0L])
  }
  if (nx == 0L || n %% nx != 0L) {
    stop(sprintf("cannot recycle length %d to %d", nx, n), call. = FALSE)
  }
  rep(x, length.out = n)
}
