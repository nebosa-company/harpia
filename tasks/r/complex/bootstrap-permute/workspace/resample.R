# Resampling toolkit. See the project brief for the exact drawing recipe
# each function must follow -- the numbers have to be reproducible.

boot_ci <- function(x, statistic, reps, seed, level = 0.95) {
  stop("not implemented")
}

perm_test <- function(x, y, statistic, reps, seed,
                      alternative = "two.sided") {
  stop("not implemented")
}

jackknife <- function(x, statistic) {
  stop("not implemented")
}

format_ci <- function(ci, digits = 3) {
  stop("not implemented")
}
