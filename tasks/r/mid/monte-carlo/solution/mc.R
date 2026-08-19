# Seeded, vectorised Monte Carlo. Every draw follows the recipe in the
# brief exactly, so the numbers are reproducible.

simulate_paths <- function(n_steps, n_paths, seed) {
  set.seed(seed)
  steps <- matrix(
    sample(c(-1L, 1L), n_steps * n_paths, replace = TRUE),
    nrow = n_steps,
    ncol = n_paths
  )
  out <- steps
  out[] <- as.integer(unlist(
    lapply(seq_len(n_paths), function(j) cumsum(steps[, j])),
    use.names = FALSE
  ))
  out
}

path_stats <- function(paths) {
  data.frame(
    path = seq_len(ncol(paths)),
    final = as.integer(paths[nrow(paths), ]),
    high = as.integer(apply(paths, 2L, max)),
    low = as.integer(apply(paths, 2L, min)),
    row.names = NULL
  )
}

ruin_rate <- function(paths, barrier) {
  if (ncol(paths) == 0L) {
    return(0)
  }
  mean(apply(paths, 2L, min) <= -barrier)
}

mc_pi <- function(n, seed) {
  set.seed(seed)
  x <- runif(n)
  y <- runif(n)
  4 * mean(x^2 + y^2 <= 1)
}
