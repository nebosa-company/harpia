# Seeded resampling: bootstrap intervals, permutation tests, jackknife.
# Every draw follows the recipe in the brief exactly, so the numbers are
# reproducible.

.check_reps <- function(reps) {
  if (!is.numeric(reps) || length(reps) != 1L || is.na(reps) ||
      reps < 1 || reps != round(reps)) {
    stop("reps must be a positive whole number", call. = FALSE)
  }
  invisible(TRUE)
}

.check_sample <- function(x) {
  if (!is.numeric(x) || length(x) == 0L) {
    stop("x must be a non-empty numeric vector", call. = FALSE)
  }
  invisible(TRUE)
}

boot_ci <- function(x, statistic, reps, seed, level = 0.95) {
  .check_sample(x)
  .check_reps(reps)
  if (!is.numeric(level) || length(level) != 1L || is.na(level) ||
      level <= 0 || level >= 1) {
    stop("level must be between 0 and 1", call. = FALSE)
  }
  reps <- as.integer(reps)
  estimate <- as.numeric(statistic(x))
  n <- length(x)

  set.seed(seed)
  replicates <- vapply(
    seq_len(reps),
    function(i) as.numeric(statistic(x[sample.int(n, n, replace = TRUE)])),
    numeric(1)
  )

  tail_p <- (1 - level) / 2
  bounds <- as.numeric(quantile(replicates, c(tail_p, 1 - tail_p),
                                type = 7, names = FALSE))
  structure(
    list(
      estimate = estimate,
      lower = bounds[[1L]],
      upper = bounds[[2L]],
      reps = reps,
      level = as.numeric(level),
      replicates = replicates
    ),
    class = "boot_ci"
  )
}

perm_test <- function(x, y, statistic, reps, seed,
                      alternative = "two.sided") {
  .check_sample(x)
  .check_sample(y)
  .check_reps(reps)
  if (!is.character(alternative) || length(alternative) != 1L ||
      is.na(alternative) ||
      !(alternative %in% c("two.sided", "greater", "less"))) {
    stop("alternative must be two.sided, greater or less", call. = FALSE)
  }
  reps <- as.integer(reps)
  observed <- as.numeric(statistic(x, y))
  pooled <- c(x, y)
  n <- length(x)
  total <- length(pooled)

  set.seed(seed)
  null_dist <- vapply(
    seq_len(reps),
    function(i) {
      idx <- sample.int(total, n)
      as.numeric(statistic(pooled[idx], pooled[-idx]))
    },
    numeric(1)
  )

  hits <- switch(
    alternative,
    two.sided = sum(abs(null_dist) >= abs(observed)),
    greater = sum(null_dist >= observed),
    less = sum(null_dist <= observed)
  )
  structure(
    list(
      observed = observed,
      p_value = (1 + hits) / (reps + 1),
      reps = reps,
      alternative = alternative,
      null_dist = null_dist
    ),
    class = "perm_test"
  )
}

jackknife <- function(x, statistic) {
  .check_sample(x)
  n <- length(x)
  if (n < 2L) {
    stop("x must have at least two values", call. = FALSE)
  }
  estimate <- as.numeric(statistic(x))
  values <- vapply(
    seq_len(n),
    function(i) as.numeric(statistic(x[-i])),
    numeric(1)
  )
  centre <- mean(values)
  list(
    estimate = estimate,
    bias = (n - 1) * (centre - estimate),
    se = sqrt((n - 1) / n * sum((values - centre)^2)),
    values = values
  )
}

format_ci <- function(ci, digits = 3) {
  if (!inherits(ci, "boot_ci")) {
    stop("expected a boot_ci object", call. = FALSE)
  }
  fmt <- paste0("%.", digits, "f")
  sprintf(
    paste0(fmt, " [", fmt, ", ", fmt, "]"),
    ci$estimate, ci$lower, ci$upper
  )
}
